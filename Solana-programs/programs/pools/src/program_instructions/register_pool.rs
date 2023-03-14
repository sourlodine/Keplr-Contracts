use crate::errors::ErrorCode;
use crate::program_accounts::*;
use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

#[derive(Accounts)]
pub struct RegisterPool<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account( init, payer = payer, seeds = [b"pool-vault", deposit_token.key().as_ref()], bump, token::mint = deposit_token, token::authority = pool_vault )]
    pub pool_vault: Account<'info, TokenAccount>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub deposit_token: Account<'info, Mint>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub rent: Sysvar<'info, Rent>,
}

impl<'info> RegisterPool<'info> {
    pub fn execute(
        ctx: Context<Self>,
        pool_weight: u64,
        is_reward_pool: bool,
    ) -> Result<()> {
        let global_account = &mut ctx.accounts.global_account;
        let deposit_token = &mut ctx.accounts.deposit_token;
        if global_account
            .pools
            .iter()
            .find(|item| item.deposit_token == deposit_token.key())
            .is_some()
        {
            return Err(ErrorCode::PoolAlreadyExists.into());
        }
        global_account.total_pool_weight += pool_weight;
        global_account.pools.push(Pool {
            is_reward_pool,
            pool_weight,
            deposit_token: deposit_token.key(),
            last_distribute_time: 0,
        });

        Ok(())
    }
}
