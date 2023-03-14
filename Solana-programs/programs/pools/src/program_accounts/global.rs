use anchor_lang::prelude::*;

#[account]
pub struct GlobalAccount {
    pub reward_token: Pubkey,

    pub rewards_per_second: u64,

    pub locked_reward_withdraw_interval: u32,

    pub locked_reward_multiplier_mul: u64,

    pub locked_reward_withdraw_count: u8,

    pub total_pool_weight: u64,

    pub lock_unit_duration: u64,

    pub lock_unit_multiplier_mul: u64,

    pub max_lock_units: u64,

    pub total_distributed_rewards: u64,

    pub pools: Vec<Pool>,
}

#[derive(Debug, Clone, AnchorSerialize, AnchorDeserialize)]
pub struct Pool {
    pub is_reward_pool: bool,

    pub pool_weight: u64,







    pub last_distribute_time: i64,
}
