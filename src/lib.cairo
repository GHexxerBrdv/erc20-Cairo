use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn name(self: @TContractState) -> ByteArray;
    fn symbol(self: @TContractState) -> ByteArray;
    fn decimals(self: @TContractState) -> u8;

    fn total_supply(self: @TContractState) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;

    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;

    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    fn mint(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
}

/// Simple contract for managing balance.
#[starknet::contract]
pub mod ERC20 {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};

    //>/ Events

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        amount: u256,
    }

    #[storage]
    pub struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        owner: ContractAddress,
    } //>/ i am not sure about default values in starknet.

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.name.write("GB_Token");
        self.symbol.write("GB-53F8");
        self.decimals.write(18_u8);
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl ERC20Impl of super::IERC20<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
            self.balances.read(owner)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();

            let sender_prev_balance = self.balances.read(sender);
            let to_prev_balance = self.balances.read(to);

            assert(sender_prev_balance >= amount, 'Insufficient balance');

            self.balances.write(sender, sender_prev_balance - amount);
            self.balances.write(to, to_prev_balance + amount);

            assert(self.balances.read(to) > to_prev_balance, 'Transaction Failed');

            self.emit(Transfer { from: sender, to: to, amount: amount });

            true
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let spender = get_caller_address();

            let spender_allowance = self.allowances.read((from, spender));

            let from_balance = self.balances.read(from);
            let to_balance = self.balances.read(to);

            assert(amount <= spender_allowance, 'Insufficient allowance');
            assert(amount <= from_balance, 'Insufficient balance');

            self.allowances.write((from, spender), spender_allowance - amount);

            self.balances.write(from, from_balance - amount);
            self.balances.write(to, to_balance + amount);

            self.emit(Transfer { from: from, to: to, amount: amount });

            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            self.allowances.write((caller, spender), amount);

            self.emit(Approval { owner: caller, spender: spender, amount: amount });

            true
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            assert(caller == self.owner.read(), 'Caller is not the owner');

            let previous_total_supply = self.total_supply.read();
            let previous_balance = self.balances.read(to);

            self.total_supply.write(previous_total_supply + amount);
            self.balances.write(to, previous_balance + amount);

            let zero_address: ContractAddress = 0.try_into().unwrap();

            self.emit(Transfer { from: zero_address, to, amount });

            true
        }

        fn burn(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();

            assert(caller == self.owner.read(), 'Caller is not the owner');

            let previous_total_supply = self.total_supply.read();
            let previous_balance = self.balances.read(to);

            self.total_supply.write(previous_total_supply - amount);
            self.balances.write(to, previous_balance - amount);

            self.emit(Transfer { from: to, to: 0.try_into().unwrap(), amount });

            true
        }
    }
}
