use crate::prelude::*;
use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account( init, payer = payer, seeds = [b"vault",token.key().as_ref()], bump, token::mint = token, token::authority = vault )]
    pub vault: Account<'info, TokenAccount>,

    #[account( init, payer = payer, seeds = [b"global-account-02"], bump, space = 100 )]
    pub global_account: Account<'info, GlobalAccount>,

    pub token: Account<'info, Mint>,

    #[account(mut)]
    pub payer: Signer<'info>,

    pub system_program: Program<'info, System>,
    pub token_program: Program<'info, Token>,
    pub rent: Sysvar<'info, Rent>,
}

impl<'info> Initialize<'info> {
    pub fn execute(
        ctx: Context<Initialize<'info>>,
        signer: [u8; 32],
        token_fee_rate: u64,
    ) -> Result<()> {
        let global = &mut ctx.accounts.global_account;
        global.signer = signer;
        global.token_fee_rate = token_fee_rate;
        Ok(())
    }
}
