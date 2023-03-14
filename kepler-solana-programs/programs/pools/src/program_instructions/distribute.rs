use crate::program_accounts::*;
use anchor_lang::prelude::*;

#[derive(Accounts)]
pub struct Distribute<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut)]
    pub user: Signer<'info>,
}

impl<'info> Distribute<'info> {
    pub fn execute(ctx: Context<Self>) -> Result<()> {
        let now = Clock::get()?.unix_timestamp;
        let global_account = &mut ctx.accounts.global_account;
        let rewards_per_second = global_account.rewards_per_second as f64;
        let total_pool_weight = global_account.total_pool_weight as f64;
        if global_account.total_pool_weight > 0 {
            let mut all_rewards = 0;
            for pool in
                global_account.pools.iter_mut().filter(|pool| pool.staking_amount > 0)
            {
                let (rewards, index_mul) = calculate_distribute(
                    pool,
                    now,
                    rewards_per_second,
                    total_pool_weight,
                );
                if rewards > 0 {
                    pool.reward_index_mul += index_mul;
                    pool.distributed_rewards += rewards;
                    all_rewards += rewards;
                }
                pool.last_distribute_time = now;
            }
            global_account.total_distributed_rewards += all_rewards;
        }
        Ok(())
    }
}

fn calculate_distribute<'a>(
    pool: &mut Pool,
    now: i64,
    rewards_per_second: f64,
    total_pool_weight: f64,
) -> (u64, u64) {
    let pool_weight = pool.pool_weight as f64;
    let last_distribute_time = pool.last_distribute_time;
    msg!("distribute,now: {}", now);
    msg!("distribute,last_distribute_time: {}", last_distribute_time);
    if last_distribute_time > 0 && now > last_distribute_time {
        let passed_time = (now - last_distribute_time) as f64;
        msg!("distribute,passed_time: {}", passed_time);
        let rewards = passed_time * rewards_per_second * pool_weight / total_pool_weight;
        msg!("distribute,rewards: {}", rewards);
        if rewards > 10000.0 {
            let amount = (pool.staking_amount + pool.weighted_staking_amount) as f64;
            let index_mul = (rewards * crate::utils::UNIT / amount) as u64;
            return (rewards as u64, index_mul);
        }
    }
    (0, 0)
}
