// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Errors {
    string constant MINT_BURN_DISABLED = "Token: Mint and Burn is disabled";
    string constant MINT_BURN_ALREADY_ENABLED = "Token: Mint and Burn is already enabled";
    string constant MINT_BURN_ALREADY_DISABLED = "Token: Mint and Burn is already disabled";
    string constant NOT_ZERO_ADDRESS = "Token: Address can not be 0x0";
    string constant NOT_APPROVED = "Token: You are not approved to spend the token";
    string constant TRANSFER_EXCEEDS_BALANCE = "Token: Transfer amount exceeds balance";
    string constant BURN_EXCEEDS_BALANCE = "Token: Burn amount exceeds balance";
    string constant INSUFFICIENT_ALLOWANCE = "Token: Insufficient allowance";
    string constant NOTHING_TO_WITHDRAW = "Token: The balance must be greater than 0";
    string constant ALLOWANCE_BELOW_ZERO = "Token: Decreased allowance below zero";
    string constant ABOVE_CAP = "Token: Amount is above the cap";
    string constant NOT_LAUNCHED = "Token: The token is not launched yet";
    string constant ALREADY_LAUNCHED = "Token: Can not change the start time anymore";
    string constant INVALID_DATE = "Token: Invalid date";

    string constant NOT_OWNER = "Ownable: Caller is not the owner";
    string constant NOT_ORACLE_OR_HANDLER = "Ownable: Caller is not the oracle or handler";
    string constant OWNABLE_NOT_ZERO_ADDRESS = "Ownable: Address can not be 0x0";
    string constant ADDRESS_IS_HANDLER = "Ownable: Address is already a Bridge Handler";
    string constant ADDRESS_IS_NOT_HANDLER = "Ownable: Address is not a Bridge Handler";

    string constant TOKEN_NOT_ALLOWED_IN_BRIDGE = "Oracle: Your token is not allowed in JM Bridge";
    string constant SET_HANDLER_ORACLE_FIRST = "Oracle: Set the handler oracle address first";
    string constant ORACLE_NOT_SET = "Oracle: No oracle set";
    string constant IS_NOT_ORACLE = "Oracle: You are not the oracle";
    string constant NOT_ALLOWED_TO_EDIT_ORACLE = "Oracle: Not allowed to edit the Handler Oracle address";
}