use anchor_lang::prelude::*;

#[error_code]
pub enum BridgeErrors {
    #[msg("Signature verification failed.")]
    SignatureVerificationFailed,

    #[msg("Transaction expired.")]
    TransactionExpired,

    #[msg("Duplicated OrderID.")]
    DuplicatedOrderId,

    #[msg("Invalid Access.")]
    InvalidAccess,

    #[msg("Error: Invalid Vault PDA")]
    InvalidVaultPDA,
}
