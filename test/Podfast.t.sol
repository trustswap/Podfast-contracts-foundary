pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/Podfast.sol";
import "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract PodFastTest is Test {
    PodFast public podFast; 
    address owner = address(0xDa327b857d678825743a45767b03F0c2E052Ed8e);
    address ecosystem = address(0x811626ae01050DEb9a9B1B1894AeaeE4eaaCAD08);

    address admin = address(0x01);
    address addr1 = address(69);
    address addr2 = address(0xABCD);
    address addr3 = address(0xDCBA);

    string name = 'TOKEN1';
    string symbol = 'TKN1';
    uint8 decimals = 18;
    uint32 taxReflection = 75; //0.75%
    uint32 taxOwner = 75; // 0.75%
    uint32 taxEcosystem = 50; // 0.50%
    uint256 supply = 5000000000e18;


    function setUp() public {
        PodFast podFastImpl = new PodFast();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(payable( address (podFastImpl)), address(admin), "");
        podFast = PodFast(payable(address(proxy)));
        vm.prank(owner);
        podFast.initialize(name, symbol, decimals, taxReflection,taxOwner,taxEcosystem, supply, owner, ecosystem);   
    }

    function testName() public {
        string memory _name = podFast.name();
        assertEq(_name, name);
    }

    function testSymbol() public {
        string memory _symbol = podFast.symbol();
        assertEq(_symbol, symbol);
    }

    function testDecimals() public {
        uint8 _decimals = podFast.decimals();
        assertEq(_decimals, decimals);
    }

    function testSupply() public {
        uint256 _supply = podFast.totalSupply();
        assertEq(_supply, supply);
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 50e18);
        vm.prank(addr2);
        podFast.transfer(addr1, 50e18);
        _supply = podFast.totalSupply();
        assertEq(_supply, supply);
    }

    function testBalanceOf() public {
        vm.prank(owner);
        uint256 _balance = podFast.balanceOf(owner);
        assertEq(_balance, supply);
    }

    function testTransferFromOwner() public {
        vm.prank(owner);
        podFast.transfer(addr1, 100e18);
        uint256 _balance = podFast.balanceOf(owner);
        assertEq(_balance, (supply - 100e18));
        _balance = podFast.balanceOf(addr1);
        assertEq(_balance, 100e18);
    }

    function testTransferFromUserToOwner() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        uint256 _balance = podFast.balanceOf(owner);
        vm.stopPrank();
        vm.startPrank(addr1);
        podFast.transfer(owner, 10e18);
        uint256 _balancePostTransfer = podFast.balanceOf(owner);
        assertEq(_balancePostTransfer - _balance, 10e18);
    }

    function testTransferFromUserToExcludedReflectUser() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        podFast.excludeFromReward(addr2);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 10e18);
        uint256 _balanceAddr1 = podFast.balanceOf(addr1);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertEq(_balanceAddr2, 1098e17);
        assertEq(_balanceAddr1, 90075e15);
    }

    function testTransferFromExcludedReflectUserToUser() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        podFast.excludeFromReward(addr1);
         vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 10e18);
        uint256 _balanceAddr1 = podFast.balanceOf(addr1);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertEq(_balanceAddr2, 109875e15);
        assertEq(_balanceAddr1, 90e18);
    }

    function testTransferFromExcludedReflectUserToExlcudedReflectUser() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        podFast.excludeFromReward(addr1);
        podFast.excludeFromReward(addr2);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 10e18);
        uint256 _balanceAddr1 = podFast.balanceOf(addr1);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertEq(_balanceAddr2, 1098e17);
        assertEq(_balanceAddr1, 90e18);
        vm.stopPrank();
        vm.startPrank(owner);
        podFast.transfer(addr3, 100e18);
        uint256 _balanceAddr3 = podFast.balanceOf(addr3);
        assertEq(_balanceAddr3, 100075e15);
    }

    function testTransferFromUserToUser() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 10e18);
        uint256 _balanceAddr1 = podFast.balanceOf(addr1);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertGt(_balanceAddr2, 1098e17);
        assertGt(_balanceAddr1, 90e18);
    }

    function testApprove() public {
        vm.startPrank(address(0));
        vm.expectRevert("PodFast: cannot approve from zero address");
        podFast.approve(addr1, 100e18);
        vm.stopPrank();
        vm.startPrank(owner);
        podFast.approve(addr1, 100e18);
        vm.expectRevert("PodFast: cannot approve to zero address");
        podFast.approve(address(0), 100e18);
        uint256 allowance = podFast.allowance(owner, addr1);
        assertEq(allowance, 100e18);
    }

    function testTransferFrom() public {
        vm.startPrank(owner);
        podFast.approve(addr1, 100e18);
        vm.stopPrank();
        vm.startPrank(addr1);
        podFast.transferFrom(owner, addr2, 100e18);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertEq(_balanceAddr2, 100e18);
        vm.stopPrank();
        vm.startPrank(addr2);
        podFast.approve(addr3, 100e18);
        vm.stopPrank();
        vm.startPrank(addr3);
        podFast.transferFrom(addr2, addr1, 100e18);
        uint256 _balanceAddr1 = podFast.balanceOf(addr1);
        assertEq(_balanceAddr1, 9875e16);
    }

    function testIncreaseAllowance() public {
        vm.startPrank(owner);
        podFast.approve(addr1, 100e18);
        uint256 allowance = podFast.allowance(owner, addr1);
        assertEq(allowance, 100e18);
        podFast.increaseAllowance(addr1, 100e18);
        uint256 allowanceIncrease = podFast.allowance(owner, addr1);
        assertEq(allowanceIncrease, 200e18);
    }

    function testDecreaseAllowance() public {
        vm.startPrank(owner);
        podFast.approve(addr1, 100e18);
        uint256 allowance = podFast.allowance(owner, addr1);
        assertEq(allowance, 100e18);
        podFast.decreaseAllowance(addr1, 100e18);
        uint256 allowanceIncrease = podFast.allowance(owner, addr1);
        assertEq(allowanceIncrease, 0);
    }

    function totalFees() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        podFast.transfer(addr3, 100e18);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 10e18);
        vm.prank(addr2);
        podFast.transfer(addr3, 10e18);
        vm.prank(addr3);
        podFast.transfer(addr1, 10e18);
        uint256 totalFee = podFast.totalFees();
        assertEq(totalFee, 75e15 * 3);
    }

    function testDeliver() public {
        vm.startPrank(owner);
        vm.expectRevert("PodFast: Excluded addresses cannot call this function");
        podFast.deliver(1000e18);
        podFast.transfer(addr1, 1000e18);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.deliver(1000e18);
        uint256 totalFee = podFast.totalFees();
        // assertEq(totalFee, 75e17);
    }

    function testIsExcludedFromReward () public {
        bool isExlcuded = podFast.isExcludedFromReward(owner);
        assertEq(isExlcuded, true);
        bool isExlcuded2 = podFast.isExcludedFromReward(addr1);
        assertEq(isExlcuded2, false);
    }

    function testReflectionFromToken() public {
        uint256 rate = podFast._getRate();
        console.log('rate', rate);
        vm.expectRevert("PodFast: Amount must be less than the Total Supply");
        podFast.reflectionFromToken((supply + 1e18), false);
        uint256 reflectionOwner = podFast.reflectionFromToken(100e18, true);
        console.log(reflectionOwner);
    }

    function testSetAllFeePercent() public {
        vm.startPrank(owner);
        vm.expectRevert("PodFast: TaxFee over limit");
        podFast.setAllFeePercent(1500, 1000, 1000);
        vm.expectRevert("PodFast: WalletFee over limit");
        podFast.setAllFeePercent(1000, 1500, 1000);
        vm.expectRevert("PodFast: EcosystemFee over limit");
        podFast.setAllFeePercent(1000, 1000, 1500);
        podFast.setAllFeePercent(1000, 1000, 1000);
    }

    function testIncludeAndExcludeFromReward() public {
        vm.startPrank(owner);
        vm.expectRevert("PodFast: Already included");
        podFast.includeInReward(addr1);
        podFast.transfer(addr1, 100e18);
        podFast.transfer(addr2, 100e18);
        vm.stopPrank();
        vm.prank(addr2);
        podFast.transfer(addr1, 50e18);
        vm.startPrank(owner);
        uint256 balanceBeforeExclusion = podFast.balanceOf(addr1);
        podFast.excludeFromReward(addr1);
        bool isExcluded = podFast.isExcludedFromReward(addr1);
        assertEq(isExcluded, true);
        podFast.includeInReward(addr1);
        bool isExcluded2 = podFast.isExcludedFromReward(addr1);
        assertEq(isExcluded2, false);
        uint256 balanceAfterExclusion = podFast.balanceOf(addr1);
        assertEq(balanceAfterExclusion, balanceBeforeExclusion);
    }

    function testExcludeFromFee() public {
        vm.startPrank(owner);
        podFast.transfer(addr1, 100e18);
        podFast.excludeFromFee(addr1);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 50e18);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertEq(_balanceAddr2, 50e18);
        bool isExlcudedFeeAddr1 = podFast.isExcludedFromFee(addr1);
        assertEq(isExlcudedFeeAddr1, true);
    }

    function testIncludeInFee () public {
        vm.startPrank(owner);
        podFast.excludeFromFee(addr1);
        bool isExlcudedFeeAddr1 = podFast.isExcludedFromFee(addr1);
        assertEq(isExlcudedFeeAddr1, true);
        podFast.transfer(addr1, 100e18);
        podFast.includeInFee(addr1);
        isExlcudedFeeAddr1 = podFast.isExcludedFromFee(addr1);
        assertEq(isExlcudedFeeAddr1, false);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr2, 50e18);
        uint256 _balanceAddr1 = podFast.balanceOf(addr1);
        uint256 _balanceAddr2 = podFast.balanceOf(addr2);
        assertGt(_balanceAddr1, 50e18);
        assertGt(_balanceAddr2, 49e18);
        assertEq(podFast.totalFees(), 375e15);
    }

    function testSetFeeWallet() public {
        vm.startPrank(owner);
        vm.expectRevert("PodFast: Can't set ZERO Address");
        podFast.setFeeWallet(payable(address(0)));
        podFast.setFeeWallet(payable(addr2));
        address feeWallet = podFast.feeWallet();
        assertEq(feeWallet, addr2);
        podFast.transfer(addr1, 100e18);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr3, 50e18);
        uint256 balanceFeeWallet = podFast.balanceOf(addr2);
        assertEq(balanceFeeWallet, 375e15);
    }

    function testSetEcoSystemWallet() public {
        vm.startPrank(owner);
        vm.expectRevert("PodFast: Can't set ZERO Address");
        podFast.setEcosystemWallet(payable(address(0)));
        podFast.setEcosystemWallet(payable(addr2));
        address feeWallet = podFast.ecoSystemWallet();
        assertEq(feeWallet, addr2);
        podFast.transfer(addr1, 100e18);
        vm.stopPrank();
        vm.prank(addr1);
        podFast.transfer(addr3, 50e18);
        uint256 balanceEcosystemWallet = podFast.balanceOf(addr2);
        assertEq(balanceEcosystemWallet, 250e15);
    }

    function testTransfer() public {
        vm.startPrank(address(0));
        vm.expectRevert("PodFast: transfer from zero address");
        podFast.transfer(addr1, 100e18);
        vm.stopPrank();
        vm.startPrank(owner);
        vm.expectRevert("PodFast: transfer to zero address");
        podFast.transfer(address(0), 100e18);
        vm.expectRevert("PodFast: Transfer amount must be greater than zero");
        podFast.transfer(addr1, 0);
    }

    function testTokenFromReflection() public {
        uint256 MAX = ~uint256(0);
        vm.expectRevert("PodFast: Amount must be less than total reflections");
        podFast.tokenFromReflection((MAX - (MAX % supply)) + 1);
        uint256 reflectionAmt = podFast.tokenFromReflection(100e18);
        assertEq(reflectionAmt, 0);
        vm.prank(owner);
        podFast.transfer(addr1, 100e18);
        vm.prank(addr1);
        podFast.transfer(addr2, 100e18);
        reflectionAmt = podFast.tokenFromReflection(98e18);
        console.log(reflectionAmt);
        assertEq(reflectionAmt, 75e15);
    }
}