use crate::program_accounts::*;
use anchor_lang::prelude::*;

#[derive(Accounts)]
pub struct InitializeUserAccount<'info> {
    #[account( init, payer = user, seeds = [b"user-account", user.key().as_ref()], bump, space = 1024)]
    pub user_account: Account<'info, UserAccount>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

impl<'info> InitializeUserAccount<'info> {
    pub fn execute(ctx: Context<InitializeUserAccount>) -> Result<()> {
        let account = &mut ctx.accounts.user_account;
        account.user = ctx.accounts.user.key();
        account.next_deposit_id = 0;
        Ok(())
    }
}
