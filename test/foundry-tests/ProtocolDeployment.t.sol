pragma solidity ^0.8.0;

import "../../contracts/compound-v2-fork/WhitePaperInterestRateModel.sol";
import "../../contracts/compound-v2-fork/ComptrollerInterface.sol";
import "../../contracts/compound-v2-fork/CErc20Delegator.sol";
import "../../contracts/compound-v2-fork/CErc20Delegate.sol";
import "../../contracts/compound-v2-fork/Comptroller.sol";
import "../../contracts/utilities/MarketAidFactory.sol";
import "../../contracts/periphery/TokenWithFaucet.sol";
import "../../contracts/utilities/MarketAid.sol";
import "../../contracts/periphery/WETH9.sol";
import "../../contracts/RubiconMarket.sol";
import "forge-std/Test.sol";

/// @notice proxy isn't used here
contract ProtocolDeploymentTest is Test {
  //========================CONSTANTS========================
  address public owner;
  address FEE_TO = 0x0000000000000000000000000000000000000FEE;
  // core contracts
  RubiconMarket market;
  Comptroller comptroller;
  // test tokens
  TokenWithFaucet TEST;
  TokenWithFaucet TUSDC;
  WETH9 WETH;
  // Pools
  WhitePaperInterestRateModel irModel;
  CErc20Delegate bathTokenImplementation;
  CErc20Delegator bathTEST;
  CErc20Delegator bathTUSDC;
  // MarketAid
  MarketAidFactory marketAidFactory;

  // deployRubiconProtocolFixture()
  function setUp() public {
    owner = msg.sender;
    // deploy Comptroller instance
    comptroller = new Comptroller();

    // deploy new Market instance and init
    market = new RubiconMarket();
    market.initialize(FEE_TO);
    market.setFeeBPS(10);

    // deploy test tokens
    TEST = new TokenWithFaucet(address(this), "Test", "TEST", 18);
    TUSDC = new TokenWithFaucet(address(this), "Test Stablecoin", "TUSDC", 6);
    WETH = new WETH9();

    // create InterestRateModel;
    // baseRate = 0.3, multiplierPerYear = 0.02
    irModel = new WhitePaperInterestRateModel(3e17, 2e16);
    bathTokenImplementation = new CErc20Delegate();
    bathTEST = new CErc20Delegator(
      address(TEST),
      ComptrollerInterface(address(comptroller)),
      irModel,
      2e26,
      "TestBathToken",
      "bathTEST",
      18,
      payable(owner),
      address(bathTokenImplementation),
      ""
    );
    bathTUSDC = new CErc20Delegator(
      address(TUSDC),
      ComptrollerInterface(address(comptroller)),
      irModel,
      2e15,
      "TestBathStablecoin",
      "bathTUSDC",
      6,
      payable(owner),
      address(bathTokenImplementation),
      ""
    );
    // support cToken market
    comptroller._supportMarket(CToken(address(bathTEST)));
    comptroller._supportMarket(CToken(address(bathTUSDC)));

    // add some $$$ to the Market
    TEST.faucet();
    TUSDC.faucet();
    TEST.approve(address(market), type(uint256).max);
    TUSDC.approve(address(market), type(uint256).max);
    // place ask and bid for TEST/TUSDC pair
    market.offer(90e6, TUSDC, 100e18, TEST, address(this), owner); // offer with custom owner and recipient
    market.offer(100e18, TEST, 110e6, TUSDC);

    // Aid for the Market
    marketAidFactory = new MarketAidFactory();
    marketAidFactory.initialize(address(market));

    // router coming soonTM
  }

  //========================MARKET_TESTS========================

  function test_MarketInitializedCorrectly() public {
    assertEq(market.initialized(), true);
  }

  function test_MarketHasTheRightAdmin() public {
    assertEq(market.owner(), address(this));
  }

  function test_MarketHasTheRightFeeRecipient() public {
    assertEq(market.getFeeTo(), FEE_TO);
  }

  function test_MarketVariablesEnabled() public {
    assertEq(market.matchingEnabled(), true);
    assertEq(market.buyEnabled(), true);
  }

  function test_OfferHasTheRightOwnerAndRecipient() public {
    assertEq(market.getOwner(1), address(this));
    assertEq(market.getRecipient(1), owner);
  }

  //========================POOLS_TESTS========================

  function test_ComptrollerHasTheRightAdmin() public {
    assertEq(comptroller.admin(), address(this));
  }

  function test_CTokenCorrectlySpawned() public {
    (bool isListed, , bool isComped) = comptroller.markets(address(bathTEST));
    assertEq(isListed, true);
    assertEq(isComped, false);
  }
}
