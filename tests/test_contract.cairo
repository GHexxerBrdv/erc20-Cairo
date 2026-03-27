use erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn deploy_contract(name: ByteArray, owner: ContractAddress) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let constructor_args = array![owner.into()];
    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    contract_address
}

const OWNER: ContractAddress = 'OWNER'.try_into().unwrap();
const TOKEN_RECIPIENT: ContractAddress = 'RECIPIENT'.try_into().unwrap();

#[test]
fn test_token_constructor() {
    let contract_address = deploy_contract("ERC20", OWNER);

    let erc20_token = IERC20Dispatcher { contract_address };

    let token_name = erc20_token.name();
    let token_symbol = erc20_token.symbol();
    let token_decimal = erc20_token.decimals();

    assert(token_name == "GB_Token", 'Wrong token name');
    assert(token_symbol == "GB-53F8", 'Wrong token symbol');
    assert(token_decimal == 18, 'Wrong token decimal');
}

#[test]
fn test_total_supply() {
    let contract_address = deploy_contract("ERC20", OWNER);

    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();
    let mint_amount = 1000 * token_decimal.into();

    // cheat caller address to be the owner
    cheat_caller_address(contract_address, OWNER, CheatSpan::TargetCalls(1));
    erc20_token.mint(TOKEN_RECIPIENT, mint_amount);

    let supply = erc20_token.total_supply();

    assert(supply == mint_amount, 'Incorrect Supply');
}

#[test]
fn test_transfer() {
    let contract_address = deploy_contract("ERC20", OWNER);
    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();

    let amount_to_mint: u256 = 10000 * token_decimal.into();
    let amount_to_transfer: u256 = 5000 * token_decimal.into();

    // Start impersonating the owner for multiple calls
    start_cheat_caller_address(contract_address, OWNER);

    erc20_token.mint(OWNER, amount_to_mint);

    assert(erc20_token.balance_of(OWNER) == amount_to_mint, 'Incorrect minted amount');

    let receiver_previous_balance = erc20_token.balance_of(TOKEN_RECIPIENT);
    erc20_token.transfer(TOKEN_RECIPIENT, amount_to_transfer);

    stop_cheat_caller_address(contract_address);

    assert(erc20_token.balance_of(OWNER) < amount_to_mint, 'Sender balance not reduced');
    assert(
        erc20_token.balance_of(OWNER) == amount_to_mint - amount_to_transfer,
        'Wrong sender balance',
    );

    assert(
        erc20_token.balance_of(TOKEN_RECIPIENT) > receiver_previous_balance,
        'Recipient balance unchanged',
    );
    assert(erc20_token.balance_of(TOKEN_RECIPIENT) == amount_to_transfer, 'Wrong recipient amount');
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_transfer_insufficient_balance() {
    // Deploy the contract
    let contract_address = deploy_contract("ERC20", OWNER);
    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();

    // Define amounts: only 5,000 tokens minted, but attempting to transfer 10,000
    let mint_amount: u256 = 5000 * token_decimal.into();
    let transfer_amount: u256 = 10000 * token_decimal.into();

    // Start impersonating the owner
    start_cheat_caller_address(contract_address, OWNER);

    // Mint only 5,000 tokens to the owner
    erc20_token.mint(OWNER, mint_amount);

    // Verify the mint was successful
    assert(erc20_token.balance_of(OWNER) == mint_amount, 'Mint failed');

    // Attempt to transfer more than balance (10,000 tokens when only 5,000 exist)
    // This should panic with 'Insufficient amount'
    erc20_token.transfer(TOKEN_RECIPIENT, transfer_amount);

    // Stop impersonating the owner
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_approve() {
    let contract_address = deploy_contract("ERC20", OWNER);
    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();
    let mint_amount: u256 = 10000 * token_decimal.into();
    let approval_amount: u256 = 5000 * token_decimal.into();

    // Start impersonating the owner
    start_cheat_caller_address(contract_address, OWNER);

    // Mint tokens to the owner first
    erc20_token.mint(OWNER, mint_amount);

    // Verify mint succeeded
    assert(erc20_token.balance_of(OWNER) == mint_amount, 'Mint failed');

    // Owner approves the recipient to spend tokens
    erc20_token.approve(TOKEN_RECIPIENT, approval_amount);

    // Stop impersonating the owner
    stop_cheat_caller_address(contract_address);

    // Verify the allowance was set
    assert(erc20_token.allowance(OWNER, TOKEN_RECIPIENT) > 0, 'Incorrect allowance');
    assert(
        erc20_token.allowance(OWNER, TOKEN_RECIPIENT) == approval_amount, 'Wrong allowance amount',
    );
}

#[test]
fn test_transfer_from() {
    let contract_address = deploy_contract("ERC20", OWNER);
    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();
    let mint_amount: u256 = 10000 * token_decimal.into();
    let transfer_amount: u256 = 5000 * token_decimal.into();

    start_cheat_caller_address(contract_address, OWNER);

    erc20_token.mint(OWNER, mint_amount);

    assert(erc20_token.balance_of(OWNER) == mint_amount, 'Mint failed');

    let spender: ContractAddress = 'SPENDER'.try_into().unwrap();
    erc20_token.approve(spender, transfer_amount);

    stop_cheat_caller_address(contract_address);

    assert(erc20_token.allowance(OWNER, spender) == transfer_amount, 'Approval failed');

    let owner_balance_before = erc20_token.balance_of(OWNER);
    let recipient_balance_before = erc20_token.balance_of(TOKEN_RECIPIENT);
    let allowance_before = erc20_token.allowance(OWNER, spender);

    cheat_caller_address(contract_address, spender, CheatSpan::TargetCalls(1));
    erc20_token.transfer_from(OWNER, TOKEN_RECIPIENT, 5000 * token_decimal.into());

    assert(
        erc20_token.balance_of(OWNER) == owner_balance_before - transfer_amount,
        'Owner balance wrong',
    );

    assert(
        erc20_token.balance_of(TOKEN_RECIPIENT) == recipient_balance_before + transfer_amount,
        'Recipient balance wrong',
    );

    assert(
        erc20_token.allowance(OWNER, spender) == allowance_before - transfer_amount,
        'Allowance not reduced',
    );
}

#[test]
#[should_panic(expected: ('Insufficient allowance',))]
fn test_transfer_from_insufficient_allowance() {
    // Deploy the contract
    let contract_address = deploy_contract("ERC20", OWNER);
    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();

    // Define amounts: 10,000 tokens to mint, 5,000 to approve
    let mint_amount: u256 = 10000 * token_decimal.into();
    let approval_amount: u256 = 5000 * token_decimal.into();

    // Start impersonating the owner
    start_cheat_caller_address(contract_address, OWNER);

    // Mint tokens to the owner
    erc20_token.mint(OWNER, mint_amount);

    let spender: ContractAddress = 'SPENDER'.try_into().unwrap();

    // Owner approves SPENDER to spend 5,000 tokens
    erc20_token.approve(spender, approval_amount);

    // Stop impersonating owner
    stop_cheat_caller_address(contract_address);

    // Attempt to transfer more than approved (6,000 instead of 5,000)
    // This should panic with 'amount exceeds allowance'
    cheat_caller_address(contract_address, spender, CheatSpan::TargetCalls(1));
    erc20_token.transfer_from(OWNER, TOKEN_RECIPIENT, 6000 * token_decimal.into());
}

#[test]
#[should_panic(expected: ('Insufficient balance',))]
fn test_transfer_from_insufficient_balance() {
    // Deploy the contract
    let contract_address = deploy_contract("ERC20", OWNER);
    let erc20_token = IERC20Dispatcher { contract_address };

    let token_decimal = erc20_token.decimals();

    // Define amounts: only 1,000 tokens minted, but 2,000 approved and attempted
    let mint_amount: u256 = 1000 * token_decimal.into();
    let approval_amount: u256 = 2000 * token_decimal.into();
    let transfer_amount: u256 = 2000 * token_decimal.into();

    // Start impersonating the owner
    start_cheat_caller_address(contract_address, OWNER);

    // Mint only 1,000 tokens to the owner
    erc20_token.mint(OWNER, mint_amount);

    let spender: ContractAddress = 'SPENDER'.try_into().unwrap();

    // Owner approves SPENDER to spend 2,000 tokens (more than balance)
    erc20_token.approve(spender, approval_amount);

    // Stop impersonating owner
    stop_cheat_caller_address(contract_address);

    // Spender has sufficient allowance but owner doesn't have enough balance
    // This should panic with 'amount exceeds balance'
    cheat_caller_address(contract_address, spender, CheatSpan::TargetCalls(1));
    erc20_token.transfer_from(OWNER, TOKEN_RECIPIENT, transfer_amount);
}
