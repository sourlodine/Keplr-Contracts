use anchor_lang::prelude::*;
use anchor_spl::token::{self, TokenAccount, Transfer};

pub const UNIT: f64 = 1000000000.0;

pub fn transer_deposit_token_to_user<'info, T: Id + Clone>(
    token_program: &Program<'info, T>,
    pool_vault: &Account<'info, TokenAccount>,
    user_token_account: &Account<'info, TokenAccount>,
    amount: u64,
) -> Result<()> {
    let (pda, bump) = Pubkey::find_program_address(&[b"pool-vault", user_token_account.mint.as_ref()], &crate::id());
    if pda != pool_vault.key() {
        return Err(super::errors::ErrorCode::InvalidStakeVaultPDA.into());
    }

    token::transfer(
        CpiContext::new_with_signer(
            token_program.to_account_info(),
            Transfer {
                from: pool_vault.to_account_info(),
                to: user_token_account.to_account_info(),
                authority: pool_vault.to_account_info(),
            },
            &[&[b"pool-vault", user_token_account.mint.as_ref(), &[bump]]],
        ),
        amount,
    )?;
    Ok(())
}

pub fn transer_reward_to_user<'info, T: Id + Clone>(
    token_program: &Program<'info, T>,
    reward_vault: &Account<'info, TokenAccount>,
    user_reward_token_account: &Account<'info, TokenAccount>,
    amount: u64,
) -> Result<()> {
    let (pda, bump) = Pubkey::find_program_address(&[b"reward-vault", user_reward_token_account.mint.as_ref()], &crate::id());
    if pda != reward_vault.key() {
        return Err(super::errors::ErrorCode::InvalidRewardVaultPDA.into());
    }
    token::transfer(
        CpiContext::new_with_signer(
            token_program.to_account_info(),
            Transfer {
                from: reward_vault.to_account_info(),
                to: user_reward_token_account.to_account_info(),
                authority: reward_vault.to_account_info(),
            },
            &[&[b"reward-vault", user_reward_token_account.mint.as_ref(), &[bump]]],
        ),
        amount,
    )?;
    Ok(())
}

pub fn calculate_weighted_claim_amount(amount: u64, multiplier: u64) -> u64 {
    let amount = amount as f64;
    let multiplier = multiplier as f64;
    (multiplier / UNIT * amount) as u64
}
