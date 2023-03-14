use anchor_lang::prelude::*;

#[account]
pub struct GlobalAccount {
    pub signer: [u8; 32],

    pub token_fee_rate: u64,
}
