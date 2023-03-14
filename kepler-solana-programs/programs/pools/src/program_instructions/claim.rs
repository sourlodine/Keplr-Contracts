use crate::errors::ErrorCode;
use crate::program_accounts::*;
use crate::utils;
use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token};

#[derive(Accounts)]
pub struct Claim<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut, constraint = user_account.user == user.key() )]
    pub user_account: Account<'info, UserAccount>,

    pub deposit_token: Account<'info, Mint>,

    #[account(mut)]
    pub user: Signer<'info>,

    pub token_program: Program<'info, Token>,
}

fn claim_other_token(ctx: Context<Claim>, deposit_id: u16) -> Result<()> {
    let global_account = &mut ctx.accounts.global_account;
    let user_account = &mut ctx.accounts.user_account;
    let deposit_token = &mut ctx.accounts.deposit_token;
    let next_claim_id = user_account.next_claim_id;
    let locked_reward_multiplier_mul = global_account.locked_reward_multiplier_mul;
    let reward_token = global_account.reward_token;
    let mut iter = global_account.pools.iter_mut();
    let reward_pool = iter.find(|item| item.deposit_token == reward_token);
    let deposit_pool = iter.find(|item| item.deposit_token == deposit_token.key());
    let deposit = user_account.deposits.iter_mut().find(|item| item.id == deposit_id);
    match (deposit_pool, reward_pool, deposit) {
        (None, _, _) => Err(ErrorCode::DepositPoolNotFound.into()),
        (_, None, _) => Err(ErrorCode::RewardPoolNotFound.into()),
        (_, _, None) => Err(ErrorCode::InvalidDepositId.into()),
        (Some(deposit_pool), Some(reward_pool), Some(deposit)) => {
            if deposit.deposit_token != deposit_pool.deposit_token {
                return Err(ErrorCode::InvalidDepositToken.into());
            }
            let amount = calculate_rewards(&deposit, deposit_pool.reward_index_mul);
            if amount == 0 {
                return Err(ErrorCode::ZeroClaimAmount.into());
            }

            deposit_pool.total_locked_rewards += amount;
            deposit.reward_index_mul = deposit_pool.reward_index_mul;

            reward_pool.staking_amount += amount;
            let weighted_amount = utils::calculate_weighted_claim_amount(
                amount,
                locked_reward_multiplier_mul,
            );
            reward_pool.weighted_staking_amount += weighted_amount;
            let claim =
                deposit.new_claim(next_claim_id, amount, reward_pool.reward_index_mul)?;
            user_account.claims.push(claim);
            user_account.next_claim_id += 1;
            Ok(())
        }
    }
}

fn claim_reward_token(ctx: Context<Claim>, deposit_id: u16) -> Result<()> {
    let global_account = &mut ctx.accounts.global_account;
    let user_account = &mut ctx.accounts.user_account;
    let next_claim_id = user_account.next_claim_id;
    let locked_reward_multiplier_mul = global_account.locked_reward_multiplier_mul;
    let reward_token = global_account.reward_token;

    let mut iter = global_account.pools.iter_mut();
    let reward_pool = iter.find(|item| item.deposit_token == reward_token);
    let deposit = user_account.deposits.iter_mut().find(|item| item.id == deposit_id);
    match (reward_pool, deposit) {
        (None, _) => Err(ErrorCode::RewardPoolNotFound.into()),
        (_, None) => Err(ErrorCode::InvalidDepositId.into()),
        (Some(reward_pool), Some(deposit)) => {
            if deposit.deposit_token != reward_pool.deposit_token {
                return Err(ErrorCode::InvalidDepositToken.into());
            }
            let pool_index_mul = reward_pool.reward_index_mul;
            let amount = calculate_rewards(&deposit, pool_index_mul);
            if amount == 0 {
                return Err(ErrorCode::ZeroClaimAmount.into());
            }
            reward_pool.total_locked_rewards += amount;
            deposit.reward_index_mul = pool_index_mul;
            reward_pool.staking_amount += amount;
            let weighted_amount = utils::calculate_weighted_claim_amount(
                amount,
                locked_reward_multiplier_mul,
            );
            reward_pool.weighted_staking_amount += weighted_amount;
            let claim = deposit.new_claim(next_claim_id, amount, pool_index_mul)?;
            user_account.claims.push(claim);
            user_account.next_claim_id += 1;
            Ok(())
        }
    }
}

impl<'info> Claim<'info> {
    pub fn execute(ctx: Context<Claim>, deposit_id: u16) -> Result<()> {
        if ctx.accounts.global_account.reward_token == ctx.accounts.deposit_token.key() {
            claim_reward_token(ctx, deposit_id)
        } else {
            claim_other_token(ctx, deposit_id)
        }
    }
}

fn calculate_rewards(deposit: &Deposit, reward_index_mul: u64) -> u64 {
    let pool_index = reward_index_mul as f64;
    let depoist_index = deposit.reward_index_mul as f64;
    let diff_index = pool_index - depoist_index;
    msg!("claim,pool_index: {}", pool_index);
    msg!("claim,depoist_index: {}", depoist_index);
    msg!("claim,diff_index: {}", diff_index);
    if diff_index > 0. {
        let amount = (deposit.amount + deposit.weighted_amount) as f64;
        msg!("claim,deposit_amount: {}", amount);
        let rewards = (diff_index * amount / utils::UNIT) as u64;
        msg!("claim,rewards: {}", rewards);
        rewards
    } else {
        0
    }
}
