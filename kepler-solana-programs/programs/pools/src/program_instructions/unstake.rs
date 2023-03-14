use crate::errors::ErrorCode;
use crate::program_accounts::*;
use crate::utils;
use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount};

#[derive(Accounts)]
pub struct Unstake<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut, constraint = pool_vault.mint == user_token_account.mint)]
    pub pool_vault: Account<'info, TokenAccount>,

    #[account( mut, constraint = user_account.user == user.key() )]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut)]
    pub user: Signer<'info>,

    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,

    pub token_program: Program<'info, Token>,
}

impl<'info> Unstake<'info> {
    pub fn execute(ctx: Context<Unstake<'info>>, deposit_id: u16) -> Result<()> {
        let global_account = &mut ctx.accounts.global_account;
        let user_account = &mut ctx.accounts.user_account;
        let user_token_account = &mut ctx.accounts.user_token_account;

        let deposit =
            user_account.deposits.iter().filter(|item| item.id == deposit_id).next();

        let pool = global_account
            .pools
            .iter_mut()
            .find(|item| item.deposit_token == user_token_account.mint);

        match (deposit, pool) {
            (None, _) => Err(ErrorCode::InvalidDepositId.into()),
            (_, None) => Err(ErrorCode::PoolNotFound.into()),
            (Some(deposit), Some(pool)) => {
                msg!("deposit :{:?}", &deposit);
                pool.staking_amount -= deposit.amount;
                pool.weighted_staking_amount -= deposit.weighted_amount;
                utils::transer_deposit_token_to_user(
                    &ctx.accounts.token_program,
                    &ctx.accounts.pool_vault,
                    &ctx.accounts.user_token_account,
                    deposit.amount,
                )?;
                user_account.deposits.retain(|item| item.id != deposit_id);
                Ok(())
            }
        }
    }
}
