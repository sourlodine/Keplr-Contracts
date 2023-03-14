use anchor_lang::prelude::*;
pub(crate) mod prelude {
    pub use super::errors::BridgeErrors;
    pub use super::program_accounts::*;
    pub use super::program_instructions::*;
}

mod errors;
mod program_accounts;
mod program_instructions;
mod utils;
use program_instructions::{
    apply_token::*, claim_token::*, initialize::*, initialize_user_account::*,
};

declare_id!("AaYvypao2X3E44EzkuytSR1MbD3cF2UTRn4nNiYoZQLE");

#[program]
pub mod bridge {
    use super::*;
    pub fn initialize(
        ctx: Context<Initialize>,
        signer: [u8; 32],
        token_fee_rate: u64,
    ) -> Result<()> {
        Initialize::execute(ctx, signer, token_fee_rate)
    }

    pub fn initialize_user_account(ctx: Context<InitializeUserAccount>) -> Result<()> {
        InitializeUserAccount::execute(ctx)
    }

    pub fn apply_token(
        ctx: Context<ApplyToken>,
        order_id: [u8; 32],
        applicant: [u8; 32],
        receipient: [u8; 32],
        from_chain_id: [u8; 8],
        from_token: [u8; 32],
        amount: [u8; 8],
        to_chain_id: [u8; 8],
        deadline: [u8; 8],
        signature: [u8; 64],
    ) -> Result<()> {
        ApplyToken::execute(
            ctx,
            order_id,
            applicant,
            receipient,
            from_chain_id,
            from_token,
            amount,
            to_chain_id,
            deadline,
            signature,
        )
    }

    pub fn claim_token(
        ctx: Context<ClaimToken>,
        order_id: [u8; 32],
        applicant: [u8; 32],
        receipient: [u8; 32],
        to_chain_id: [u8; 8],
        to_token: [u8; 32],
        amount: [u8; 8],
        deadline: [u8; 8],
        signature: [u8; 64],
    ) -> Result<()> {
        ClaimToken::execute(
            ctx,
            order_id,
            applicant,
            receipient,
            to_chain_id,
            to_token,
            amount,
            deadline,
            signature,
        )
    }
}
