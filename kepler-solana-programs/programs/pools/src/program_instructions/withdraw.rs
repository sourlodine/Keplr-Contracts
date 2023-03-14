use crate::errors::ErrorCode;
use crate::program_accounts::*;
use crate::utils;
use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut, constraint = reward_vault.mint == global_account.reward_token )]
    pub reward_vault: Account<'info, TokenAccount>,

    #[account(mut, constraint = user_account.user == user.key()  )]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut, constraint = user_reward_token_account.mint == global_account.reward_token)]
    pub user_reward_token_account: Account<'info, TokenAccount>,

    pub deposit_token: Account<'info, Mint>,

    #[account(mut)]
    pub user: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

impl<'info> Withdraw<'info> {
    pub fn execute(ctx: Context<Withdraw>, claim_id: u16) -> Result<()> {
        let is_reward_token =
            ctx.accounts.global_account.reward_token == ctx.accounts.deposit_token.key();
        let global_account = &mut ctx.accounts.global_account;
        let deposit_token = &mut ctx.accounts.deposit_token;
        let user_account = &mut ctx.accounts.user_account;
        let claim = user_account.claims.iter_mut().find(|item| item.id == claim_id);
        let reward_token = global_account.reward_token;

        let max_withdraw_count = global_account.locked_reward_withdraw_count;
        let multiplier_mul = global_account.locked_reward_multiplier_mul;
        let withdraw_interval = global_account.locked_reward_withdraw_interval;
        let mut iter = global_account.pools.iter_mut();
        match (iter.find(|item| item.deposit_token == reward_token), claim) {
            (None, _) => Err(ErrorCode::RewardPoolNotFound.into()),
            (_, None) => Err(ErrorCode::InvalidClaimId.into()),
            (Some(reward_pool), Some(claim)) => {
                msg!("claim :{:?}", &claim);

                let now = Clock::get()?.unix_timestamp;
                msg!("now: {}", now);
                let expect_withdrawn_count = std::cmp::min(
                    (now - claim.lock_time) / (withdraw_interval as i64),
                    max_withdraw_count as i64,
                );
                msg!("expect_withdrawn_count: {}", expect_withdrawn_count);

                let withdraw_count =
                    expect_withdrawn_count - claim.withdrawn_count as i64;

                msg!("withdraw_count: {}", withdraw_count);

                if withdraw_count <= 0 {
                    msg!("Invalid Withdraw Time");
                    return Err(crate::errors::ErrorCode::InvalidWithdrawTime.into());
                }

                let withdraw_amount = claim.amount / max_withdraw_count as u64;

                let weighted_withdraw_amount = utils::calculate_weighted_claim_amount(
                    withdraw_amount,
                    multiplier_mul,
                );

                let reward_amount = calcuate_rewards_amount(
                    withdraw_amount + weighted_withdraw_amount,
                    reward_pool.reward_index_mul,
                    claim.reward_index_mul,
                );
                msg!("single withdraw_amount: {}", withdraw_amount);
                msg!("single weighted_withdraw_amount: {}", weighted_withdraw_amount);
                msg!("single reward_amount: {}", reward_amount);

                let withdraw_amount = withdraw_amount * withdraw_count as u64;
                let weighted_withdraw_amount =
                    weighted_withdraw_amount * withdraw_count as u64;
                let reward_amount = reward_amount * withdraw_count as u64;

                msg!("all withdraw_amount: {}", withdraw_amount);
                msg!("all weighted_withdraw_amount: {}", weighted_withdraw_amount);
                msg!("all reward_amount: {}", reward_amount);

                reward_pool.staking_amount -= withdraw_amount;
                reward_pool.weighted_staking_amount -= weighted_withdraw_amount;

                claim.withdrawn_count += withdraw_count as u8;
                msg!("claim.withdrawn_count: {}", claim.withdrawn_count);
                if claim.withdrawn_count < max_withdraw_count {
                    msg!("update claim data");
                    claim.last_withdraw_time = now;
                    claim.remaing_amount -= withdraw_amount;
                    claim.reward_index_mul = reward_pool.reward_index_mul;
                } else {
                    msg!("remove cliam data");
                    user_account.claims.retain(|item| item.id != claim_id);
                }
                let transfer_amount = reward_amount + withdraw_amount;

                msg!("transfer_amount: {}", transfer_amount);
                msg!("vault balance: {}", ctx.accounts.reward_vault.amount);
                utils::transer_reward_to_user(
                    &ctx.accounts.token_program,
                    &ctx.accounts.reward_vault,
                    &ctx.accounts.user_reward_token_account,
                    transfer_amount,
                )?;

                if is_reward_token {
                    reward_pool.total_locked_rewards -= withdraw_amount;
                    Ok(())
                } else {
                    match iter.find(|item| item.deposit_token == deposit_token.key()) {
                        None => Err(ErrorCode::DepositPoolNotFound.into()),
                        Some(deposit_pool) => {
                            deposit_pool.total_locked_rewards -= withdraw_amount;
                            Ok(())
                        }
                    }
                }
            }
        }
    }
}

fn calcuate_rewards_amount(
    amount: u64,
    pool_index_mul: u64,
    claim_index_mul: u64,
) -> u64 {
    let index_mul = (pool_index_mul - claim_index_mul) as f64;
    return ((amount as f64) * index_mul / utils::UNIT) as u64;
}
