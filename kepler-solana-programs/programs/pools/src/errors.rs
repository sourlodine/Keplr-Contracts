use anchor_lang::prelude::*;

#[error_code]
pub enum ErrorCode {
    #[msg("ERROR_INVALID_DEPOSIT_ID")]
    InvalidDepositId = 100,

    #[msg("ERROR_DEPOSIT_POOL_NOT_FOUND")]
    DepositPoolNotFound,

    #[msg("ERROR_REWARD_POOL_NOT_FOUNDE")]
    RewardPoolNotFound,

    #[msg("ERROR_INVALID_STAKING_AMOUNT")]
    InvalidStakingAmount,

    #[msg("ERROR_POOL_NOT_FOUND")]
    PoolNotFound,

    #[msg("ERROR_INVALID_LOCK_UNIT")]
    InvalidLockUnit,

    #[msg("ERROR_INVALID_DEPOSIT_TOKEN")]
    InvalidDepositToken,

    #[msg("ERROR_POOL_ALREADY_EXISTS")]
    PoolAlreadyExists,

    #[msg("ERROR_ZERO_CLAIM_AMOUNT")]
    ZeroClaimAmount,

    #[msg("ERROR_ZERO_TOTAL_POOL_WEIGHT")]
    TotalPoolWeightIsZero,

    #[msg("ERROR_ZERO_STAKING_AMOUNT")]
    TotalStakingAmountIsZero,

    #[msg("ERROR_INVALID_CLAIM_ID")]
    InvalidClaimId,

    #[msg("ERROR_INVALID_WITHDRAW_TIME")]
    InvalidWithdrawTime,

    #[msg("ERROR_INVALID_STAKE_VAULT_PDA")]
    InvalidStakeVaultPDA,

    #[msg("ERROR_INVALID_REWARD_VAULT_PDA")]
    InvalidRewardVaultPDA,

    #[msg("ERROR_INVALID_USER_ACCOUNT_PDA")]
    InvalidUserAccountPda,
    #[msg("ERROR_INSUFFICIENT_FUND_STAKED")]
    InsufficientFundsStaked,
    #[msg("ERROR_TOKEN_IS_LOCKED")]
    StakeIsLocked,
}
