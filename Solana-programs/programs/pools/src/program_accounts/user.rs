use anchor_lang::prelude::*;

#[account]
pub struct UserAccount {
    pub user: Pubkey,
    pub next_deposit_id: u16,
    pub next_claim_id: u16,
    pub deposits: Vec<Deposit>,
    pub claims: Vec<Claim>,
}

#[derive(Debug, Clone, AnchorSerialize, AnchorDeserialize)]
pub struct Deposit {
    pub id: u16,

    pub deposit_token: Pubkey,

    pub amount: u64,

    pub reward_index_mul: u64,
    pub weighted_amount: u64,
    pub deposit_time: i64,
    pub lock_units: u8,
}

impl Deposit {
    pub fn new_claim(
        &self,
        id: u16,
        amount: u64,
        reward_index_mul: u64,
    ) -> Result<Claim> {
        let now = Clock::get()?.unix_timestamp;
        let claim = Claim {
            id,
            deposit_token: self.deposit_token,
            deposit_id: self.id,
            amount,
            remaing_amount: amount,
            reward_index_mul,
            lock_time: now,
            last_withdraw_time: now,
            withdrawn_count: 0,
        };

        Ok(claim)
    }
}

#[derive(Debug, Clone, AnchorSerialize, AnchorDeserialize)]
pub struct Claim {
    pub id: u16,

    pub deposit_token: Pubkey,

    pub deposit_id: u16,

    pub amount: u64,

    pub remaing_amount: u64,

    pub reward_index_mul: u64,

    pub lock_time: i64,

    pub last_withdraw_time: i64,

    pub withdrawn_count: u8,
}
