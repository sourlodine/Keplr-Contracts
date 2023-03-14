use crate::errors::BridgeErrors;
use anchor_lang::prelude::*;
use anchor_spl::token::{self, TokenAccount, Transfer};
use solana_program::ed25519_program::ID as ED25519_ID;
use solana_program::instruction::Instruction;
use std::convert::TryInto;
pub fn verify_ed25519_ix(ix: &Instruction, pubkey: &[u8], msg: &[u8], sig: &[u8]) -> Result<()> {
            ix.data.len()       != (16 + 64 + 32 + msg.len())
    {
    }


    Ok(())
}

pub fn check_ed25519_data(data: &[u8], pubkey: &[u8], msg: &[u8], sig: &[u8]) -> Result<()> {





    let exp_signature_offset: u16 = exp_public_key_offset + pubkey.len() as u16;
    let exp_message_data_offset: u16 = exp_signature_offset + sig.len() as u16;
    let exp_num_signatures: u8 = 1;
    let exp_message_data_size: u16 = msg.len().try_into().unwrap();


    if num_signatures != &exp_num_signatures.to_le_bytes()
        || padding != &[0]
        || signature_offset != &exp_signature_offset.to_le_bytes()
        || signature_instruction_index != &u16::MAX.to_le_bytes()
        || public_key_offset != &exp_public_key_offset.to_le_bytes()
        || public_key_instruction_index != &u16::MAX.to_le_bytes()
        || message_data_offset != &exp_message_data_offset.to_le_bytes()
        || message_data_size != &exp_message_data_size.to_le_bytes()
        || message_instruction_index != &u16::MAX.to_le_bytes()
    {
        return Err(BridgeErrors::SignatureVerificationFailed.into());
    }

    if data_pubkey != pubkey || data_msg != msg || data_sig != sig {
        return Err(BridgeErrors::SignatureVerificationFailed.into());
    }

    Ok(())
}

pub fn transer_to_user<'info, T: Id + Clone>(
    token_program: &Program<'info, T>,
    vault: &Account<'info, TokenAccount>,
    user_token_account: &Account<'info, TokenAccount>,
    amount: u64,
) -> Result<()> {
    let (pda, bump) = Pubkey::find_program_address(&[b"vault", user_token_account.mint.as_ref()], &crate::id());
    if pda != vault.key() {
        return Err(super::errors::BridgeErrors::InvalidVaultPDA.into());
    }
    token::transfer(
        CpiContext::new_with_signer(
            token_program.to_account_info(),
            Transfer {
                from: vault.to_account_info(),
                to: user_token_account.to_account_info(),
                authority: vault.to_account_info(),
            },
            &[&[b"vault", user_token_account.mint.as_ref(), &[bump]]],
        ),
        amount,
    )?;
    Ok(())
}
