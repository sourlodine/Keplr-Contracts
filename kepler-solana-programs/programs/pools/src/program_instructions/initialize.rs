use crate::program_accounts::*;
use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account( init, payer = payer, seeds = [b"reward-vault", reward_token.key().as_ref()], bump, token::mint = reward_token, token::authority = reward_vault )]
    pub reward_vault: Account<'info, TokenAccount>,

    #[account( init, payer = payer, seeds = [b"global-account"], bump, space = 2020 )]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut)]
    pub payer: Signer<'info>,
    pub reward_token: Account<'info, Mint>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub rent: Sysvar<'info, Rent>,
}

impl<'info> Initialize<'info> {
    pub fn execute(
        ctx: Context<Initialize<'info>>,
        lock_unit_duration: u64,
        lock_unit_multiplier: u64,
        max_lock_units: u64,
        rewards_per_second: u64,
        locked_reward_withdraw_interval: u32,
        locked_reward_multiplier: u64,
        locked_reward_withdraw_count: u8,
    ) -> Result<()> {
        let global = &mut ctx.accounts.global_account;
        global.lock_unit_duration = lock_unit_duration;
        global.lock_unit_multiplier_mul = lock_unit_multiplier;
        global.max_lock_units = max_lock_units;

        global.reward_token = ctx.accounts.reward_token.key();
        global.rewards_per_second = rewards_per_second;
        global.locked_reward_withdraw_interval = locked_reward_withdraw_interval;
        global.locked_reward_multiplier_mul = locked_reward_multiplier;
        global.locked_reward_withdraw_count = locked_reward_withdraw_count;
        Ok(())
    }
}
