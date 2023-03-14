pub mod errors;
mod program_accounts;
mod program_instructions;
pub mod utils;

use anchor_lang::prelude::*;
use program_instructions::{
    claim::*,
    distribute::*,
    initialize_user_account::*,
    register_pool::*,
    stake::*,
    unstake::*,
    withdraw::*,
};

declare_id!("J4PPX9AeiytJdCBhErRb8uGE5vWhKD7Fzf6GWvhbVvyY");

#[program]
pub mod pools {
    use super::*;

    pub fn initialize(
        ctx: Context<Initialize>,
        lock_unit_duration: u64,
        lock_unit_multiplier_mul: u64,
        max_lock_units: u64,
        rewards_per_second: u64,
        locked_reward_withdraw_interval: u32,
        locked_reward_multiplier_mul: u64,
        locked_reward_withdraw_count: u8,
    ) -> Result<()> {
        Initialize::execute(
            ctx,
            lock_unit_duration,
            lock_unit_multiplier_mul,
            max_lock_units,
            rewards_per_second,
            locked_reward_withdraw_interval,
            locked_reward_multiplier_mul,
            locked_reward_withdraw_count,
        )
    }

    pub fn register_pool(
        ctx: Context<RegisterPool>,
        weight: u64,
        is_reward_pool: bool,
    ) -> Result<()> {
        RegisterPool::execute(ctx, weight, is_reward_pool)
    }

    pub fn initialize_user_account(ctx: Context<InitializeUserAccount>) -> Result<()> {
        InitializeUserAccount::execute(ctx)
    }

    pub fn stake(ctx: Context<Stake>, amount: u64, lock_units: u8) -> Result<()> {
        Stake::execute(ctx, amount, lock_units)
    }

    pub fn unstake(ctx: Context<Unstake>, deposit_id: u16) -> Result<()> {
        Unstake::execute(ctx, deposit_id)
    }

    pub fn claim(ctx: Context<Claim>, deposit_id: u16) -> Result<()> {
        Claim::execute(ctx, deposit_id)
    }

    pub fn withdraw(ctx: Context<Withdraw>, claim_id: u16) -> Result<()> {
        Withdraw::execute(ctx, claim_id)
    }

    pub fn distribute(ctx: Context<Distribute>) -> Result<()> {
        Distribute::execute(ctx)
    }
}
