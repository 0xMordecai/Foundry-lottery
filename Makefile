
.PHONY: all test deploy

build :; forge build

test :; forge test

install:; forge install Cyfrin/foundry-devops --no-commit && forge install smartcontractkit/chainlink --no-commit && forge install foundry-rs/forge-std@v1.7.0 --no-commit && forge install transmissions11/solmate@v6 --no-commit

deploy-sepolia :
	@forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url https://eth-sepolia.g.alchemy.com/v2/Md9wilz1U44u3f68dguybx-WBlx2eSu8 --account Account1 --broadcast --verify --etherscan-api-key BS98EUYHCV7US7EVXJZ1GF9S9P3KVC5585 -vvvv