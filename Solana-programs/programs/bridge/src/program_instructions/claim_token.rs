use crate::prelude::*;
use anchor_lang::prelude::*;
use anchor_spl::token::{Token, TokenAccount, Transfer};
use solana_program::instruction::Instruction;
use solana_program::sysvar::instructions::{load_instruction_at_checked, ID as IX_ID};

#[derive(Accounts)]
pub struct ClaimToken<'info> {
    #[account(mut)]
    pub global_account: Account<'info, GlobalAccount>,

    #[account(mut,  constraint = vault.mint== user_token_account.mint)]
    pub vault: Account<'info, TokenAccount>,

    #[account(mut, constraint = user_account.owner == user.key())]
    pub user_account: Account<'info, UserAccount>,

    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>,

    pub user: Signer<'info>,

    #[account(address = IX_ID)]
    pub ix_sysvar: AccountInfo<'info>,

    pub token_program: Program<'info, Token>,
}

impl<'info> ClaimToken<'info> {
    pub fn execute(
        order_id: [u8; 32],
        applicant: [u8; 32],
        receipient: [u8; 32],
        to_chain_id: [u8; 8],
        to_token: [u8; 32],
        amount: [u8; 8],
        deadline: [u8; 8],
        signature: [u8; 64],
    ) -> Result<()> {
        if Clock::get()?.unix_timestamp > i64::from_be_bytes(deadline) {
            return Err(BridgeErrors::TransactionExpired.into());
        }
        let mut msg: Vec<u8> = Vec::new();
        msg.extend_from_slice(&order_id);
        msg.extend_from_slice(&applicant);
        msg.extend_from_slice(&receipient);
        msg.extend_from_slice(&to_chain_id);
        msg.extend_from_slice(&to_token);
        msg.extend_from_slice(&amount);
        msg.extend_from_slice(&deadline);
        let signer = ctx.accounts.global_account.signer;
        let instruction: Instruction = load_instruction_at_checked(0, &ctx.accounts.ix_sysvar)?;
        crate::utils::verify_ed25519_ix(&instruction, &signer, &msg, &signature)?;
        let user_account = &mut ctx.accounts.user_account;
        if user_account.token_claims.iter().any(|order| order.order_id == order_id) {
            return Err(BridgeErrors::DuplicatedOrderId.into());
        }

        if ctx.accounts.user.key().to_bytes() != receipient {
            return Err(BridgeErrors::InvalidAccess.into());
        }

        user_account.token_claims.push(TokenClaim {
            order_id,
            amount,
        });

        crate::utils::transer_to_user(
            &ctx.accounts.token_program,
            &ctx.accounts.vault,
            &ctx.accounts.user_token_account,
            u64::from_be_bytes(amount),
        )?;
        Ok(())
    }
}

impl<'info> From<&ClaimToken<'info>> for CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
    fn from(accounts: &ClaimToken<'info>) -> Self {
        let cpi_program = accounts.token_program.to_account_info();
        let cpi_accounts = Transfer {
            from: accounts.vault.to_account_info(),
            to: accounts.user_token_account.to_account_info(),
            authority: accounts.vault.to_account_info(),
        };

        CpiContext::new(cpi_program, cpi_accounts)
    }
}
