use anchor_lang::prelude::*;

#[account]
pub struct UserAccount {
    pub owner: Pubkey,
    pub token: Pubkey,

    pub token_applies: Vec<TokenApply>,

    pub token_claims: Vec<TokenClaim>,
}

#[derive(Debug, Clone, AnchorSerialize, AnchorDeserialize)]
pub struct TokenApply {
    pub order_id: [u8; 32],

    pub amount: [u8; 8],
}

#[derive(Debug, Clone, AnchorSerialize, AnchorDeserialize)]
pub struct TokenClaim {
    pub order_id: [u8; 32],

    pub amount: [u8; 8],
}
