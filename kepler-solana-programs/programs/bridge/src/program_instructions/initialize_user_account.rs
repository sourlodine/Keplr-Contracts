use crate::prelude::*;
use anchor_lang::prelude::*;
use anchor_spl::token::Mint;

#[derive(Accounts)]
pub struct InitializeUserAccount<'info> {
    #[account( init, payer = user, seeds = [b"user-account", token.key().as_ref(), user.key().as_ref()], bump, space = 1800 )]
    pub user_account: Account<'info, UserAccount>,
    #[account(mut)]
    pub user: Signer<'info>,

    pub token: Account<'info, Mint>,

    pub system_program: Program<'info, System>,
}

impl<'info> InitializeUserAccount<'info> {
    pub fn execute(ctx: Context<InitializeUserAccount>) -> Result<()> {
        let account = &mut ctx.accounts.user_account;
        account.owner = ctx.accounts.user.key();
        account.token = ctx.accounts.token.key();
        Ok(())
    }
}
