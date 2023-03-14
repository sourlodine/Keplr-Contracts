use crate::program_accounts::*;
use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

#[derive(Accounts)]
pub struct Stake<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut,  constraint = pool_vault.mint== user_token_account.mint)]
    pub pool_vault: Account<'info, TokenAccount>,

    #[account( mut, constraint = user_account.user == user.key())]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,

    #[account(mut)]
    pub user: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

impl<'info> From<&Stake<'info>> for CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
    fn from(accounts: &Stake<'info>) -> Self {
        let cpi_program = accounts.token_program.to_account_info();
        let cpi_accounts = Transfer {
            from: accounts.user_token_account.to_account_info(),
            to: accounts.pool_vault.to_account_info(),
            authority: accounts.user.to_account_info(),
        };

        CpiContext::new(cpi_program, cpi_accounts)
    }
}

pub fn calculate_weighted_amount(
    amount: u64,
    lock_units: u8,
    lock_unit_multiplier_mul: u64,
) -> u64 {
    let amount = amount as f64;
    let lock_units = lock_units as u64;
    let multiplier = (lock_units * lock_unit_multiplier_mul) as f64;
    (amount * multiplier / crate::utils::UNIT) as u64
}

impl<'info> Stake<'info> {
    pub fn execute(ctx: Context<Stake>, amount: u64, lock_units: u8) -> Result<()> {
        let global_account = &mut ctx.accounts.global_account;
        let user_account = &mut ctx.accounts.user_account;
        let user_token_account = &mut ctx.accounts.user_token_account;
        if amount <= 0 {
            return Err(crate::errors::ErrorCode::InvalidStakingAmount.into());
        }

        if u64::from(lock_units) > global_account.max_lock_units {
            return Err(crate::errors::ErrorCode::InvalidLockUnit.into());
        }
        let lock_unit_multiplier_mul = global_account.lock_unit_multiplier_mul;

        let pool = global_account
            .pools
            .iter_mut()
            .find(|item| item.deposit_token == user_token_account.mint);

        match pool {
            None => Err(crate::errors::ErrorCode::PoolNotFound.into()),
            Some(pool) => {
                let deposit_id = user_account.next_deposit_id;
                let weighted_amount = calculate_weighted_amount(
                    amount,
                    lock_units,
                    lock_unit_multiplier_mul,
                );

                let deposit = Deposit {
                    id: deposit_id,
                    amount,
                    deposit_token: user_token_account.mint,
                    reward_index_mul: pool.reward_index_mul,
                    weighted_amount,
                    deposit_time: Clock::get()?.unix_timestamp,
                    lock_units,
                };

                user_account.deposits.push(deposit);
                user_account.next_deposit_id += 1;
                pool.weighted_staking_amount += weighted_amount;
                pool.staking_amount += amount;
                token::transfer((&*ctx.accounts).into(), amount)?;
                Ok(())
            }
        }
    }
}
