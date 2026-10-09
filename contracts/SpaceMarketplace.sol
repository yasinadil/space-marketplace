// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SpaceMarketplace (v2)
/// @notice A fixed set of "spaces" (DAO memberships) held under a Harberger-style, continuously
///         streamed subscription. The holder pre-funds a WETH balance that streams to the protocol
///         receiver at `SUBSCRIBE_RATE`% per year of the highest standing offer on the space. Anyone
///         can bid; the holder may sell to the highest bidder at any time, and once the holder's
///         balance runs out anyone can force the sale ("foreclosure").
/// @dev    Accounting is lazy: each space stores `balance` as of `subscTime` and streams at
///         `subscBurn` wei/second. Every state-changing entry point settles the stream first
///         (`_settle`), mutates, then re-prices the stream (`_reprice`). This keeps the invariant
///             weth.balanceOf(this) == Σ space.balance + Σ escrowed offers + receiverBal
///         true at every block boundary.
contract SpaceMarketplace is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant NUM_SPACES = 100;
    /// @notice Balance (as % of highest offer) below which anyone may force-accept the top offer.
    uint256 public constant MIN_SUBSCRIBE = 0;
    /// @notice Percent of the highest offer streamed to the receiver per year.
    uint256 public constant SUBSCRIBE_RATE = 10;
    uint256 public constant MIN_DEPOSIT = 10 gwei;

    IERC20 public immutable weth;
    address public receiver;
    uint256 public receiverBal;

    /// @dev Field order matches v1 so the existing frontend ABI for `spaces(uint256)` still decodes.
    struct Space {
        uint256 spaceNo;
        bool exists;
        address owner;
        uint256 balance; // holder's prepaid balance as of `subscTime`
        uint256 highestOffer; // sale price offered by `highestOfferer`
        address highestOfferer;
        string spaceUri;
        uint256 subscTime; // last settlement timestamp
        uint256 subscBurn; // wei per second streamed to the receiver
        uint256 subscOffer; // bidder's escrowed prepaid balance, becomes `balance` on acceptance
    }

    mapping(uint256 => Space) public spaces;

    event SpaceClaimed(uint256 indexed spaceId, address indexed owner, uint256 deposit);
    event Deposited(uint256 indexed spaceId, uint256 amount);
    event Withdrawn(uint256 indexed spaceId, uint256 amount);
    event NewOffer(uint256 indexed spaceId, address indexed offerer, uint256 amount);
    event OfferRetracted(uint256 indexed spaceId, address indexed offerer);
    event OfferAccepted(
        uint256 indexed spaceId, address indexed from, address indexed to, uint256 price
    );
    event SpaceTransferred(uint256 indexed spaceId, address indexed from, address indexed to);
    event SpaceUriSet(uint256 indexed spaceId, string uri);
    event RevenueClaimed(address indexed receiver, uint256 amount);
    event ReceiverUpdated(address indexed receiver);

    error InvalidSpace();
    error SpaceAlreadyClaimed();
    error SpaceNotFound();
    error NotSpaceOwner();
    error NotHighestOfferer();
    error OwnerCannotOffer();
    error OfferTooLow();
    error NoOffer();
    error OwnerDefended();
    error AmountTooLow();
    error InsufficientBalance();
    error ZeroAddress();
    error NotNftOwner();

    modifier spaceExists(uint256 spaceId) {
        if (!spaces[spaceId].exists) revert SpaceNotFound();
        _;
    }

    modifier onlySpaceOwner(uint256 spaceId) {
        if (!spaces[spaceId].exists) revert SpaceNotFound();
        if (spaces[spaceId].owner != msg.sender) revert NotSpaceOwner();
        _;
    }

    constructor(IERC20 _weth) Ownable(msg.sender) {
        if (address(_weth) == address(0)) revert ZeroAddress();
        weth = _weth;
        receiver = msg.sender;
    }

    // ------------------------------------------------------------------
    // Holder actions
    // ------------------------------------------------------------------

    function claimSpace(uint256 spaceId, uint256 amount) external nonReentrant {
        if (spaceId == 0 || spaceId > NUM_SPACES) revert InvalidSpace();
        Space storage space = spaces[spaceId];
        if (space.exists) revert SpaceAlreadyClaimed();

        space.exists = true;
        space.spaceNo = spaceId;
        space.owner = msg.sender;
        space.balance = amount;
        space.subscTime = block.timestamp;
        _reprice(space);

        weth.safeTransferFrom(msg.sender, address(this), amount);
        emit SpaceClaimed(spaceId, msg.sender, amount);
    }

    /// @dev v1 bug: added `amount` before settling, so topping up a depleted space handed the whole
    ///      deposit to the receiver.
    function deposit(uint256 spaceId, uint256 amount)
        external
        nonReentrant
        onlySpaceOwner(spaceId)
    {
        if (amount < MIN_DEPOSIT) revert AmountTooLow();
        Space storage space = spaces[spaceId];
        _settle(space);
        space.balance += amount;

        weth.safeTransferFrom(msg.sender, address(this), amount);
        emit Deposited(spaceId, amount);
    }

    /// @dev v1 bug: re-settled without moving `subscTime`, charging the elapsed stream twice.
    function withdraw(uint256 spaceId, uint256 amount)
        external
        nonReentrant
        onlySpaceOwner(spaceId)
    {
        Space storage space = spaces[spaceId];
        _settle(space);
        if (amount > space.balance) revert InsufficientBalance();
        space.balance -= amount;

        weth.safeTransfer(msg.sender, amount);
        emit Withdrawn(spaceId, amount);
    }

    function transferSpace(uint256 spaceId, address newOwner)
        external
        nonReentrant
        onlySpaceOwner(spaceId)
    {
        if (newOwner == address(0)) revert ZeroAddress();
        Space storage space = spaces[spaceId];
        _settle(space);

        // An owner can't hold a bid on their own space; refund it if the recipient was the bidder.
        uint256 refund;
        if (space.highestOfferer == newOwner) refund = _clearOffer(space);
        space.owner = newOwner;
        _reprice(space);

        if (refund > 0) weth.safeTransfer(newOwner, refund);
        emit SpaceTransferred(spaceId, msg.sender, newOwner);
    }

    function setSpaceUri(uint256 spaceId, uint256 nftTokenId, address nftContractAddress)
        external
        onlySpaceOwner(spaceId)
    {
        IERC721Metadata nft = IERC721Metadata(nftContractAddress);
        if (nft.ownerOf(nftTokenId) != msg.sender) revert NotNftOwner();
        string memory uri = nft.tokenURI(nftTokenId);
        spaces[spaceId].spaceUri = uri;
        emit SpaceUriSet(spaceId, uri);
    }

    // ------------------------------------------------------------------
    // Bidder actions
    // ------------------------------------------------------------------

    /// @notice Bid `amount` for the space and escrow `subscOffer` as your prepaid balance if accepted.
    /// @dev v1 bug: overwrote `highestOfferer` before refunding it, so the outbid party's escrow was
    ///      paid to the new bidder.
    function offer(uint256 spaceId, uint256 amount, uint256 subscOffer)
        external
        nonReentrant
        spaceExists(spaceId)
    {
        Space storage space = spaces[spaceId];
        if (space.owner == msg.sender) revert OwnerCannotOffer();
        if (amount <= space.highestOffer) revert OfferTooLow();

        _settle(space);
        address prevOfferer = space.highestOfferer;
        uint256 refund = _clearOffer(space);

        space.highestOfferer = msg.sender;
        space.highestOffer = amount;
        space.subscOffer = subscOffer;
        _reprice(space);

        weth.safeTransferFrom(msg.sender, address(this), amount + subscOffer);
        if (refund > 0) weth.safeTransfer(prevOfferer, refund);
        emit NewOffer(spaceId, msg.sender, amount);
    }

    function retractOffer(uint256 spaceId) external nonReentrant {
        Space storage space = spaces[spaceId];
        if (space.highestOfferer != msg.sender) revert NotHighestOfferer();

        _settle(space);
        uint256 refund = _clearOffer(space);
        _reprice(space);

        weth.safeTransfer(msg.sender, refund);
        emit OfferRetracted(spaceId, msg.sender);
    }

    /// @notice Sell to the highest bidder. The holder can always accept; anyone can once the holder's
    ///         balance has fallen to `MIN_SUBSCRIBE`% of the top offer (foreclosure).
    /// @dev v1 bugs: refunded the stale, unsettled balance (double-paying the streamed amount) and
    ///      pulled the new deposit from the *accepting* party instead of using the bidder's escrow.
    function acceptOffer(uint256 spaceId) external nonReentrant spaceExists(spaceId) {
        Space storage space = spaces[spaceId];
        if (space.highestOfferer == address(0)) revert NoOffer();

        _settle(space);
        if (msg.sender != space.owner && space.balance > (space.highestOffer * MIN_SUBSCRIBE) / 100)
        {
            revert OwnerDefended();
        }

        address seller = space.owner;
        address buyer = space.highestOfferer;
        uint256 price = space.highestOffer;
        uint256 payout = price + space.balance;

        space.owner = buyer;
        space.balance = space.subscOffer;
        space.highestOfferer = address(0);
        space.highestOffer = 0;
        space.subscOffer = 0;
        _reprice(space);

        weth.safeTransfer(seller, payout);
        emit OfferAccepted(spaceId, seller, buyer, price);
    }

    // ------------------------------------------------------------------
    // Protocol revenue
    // ------------------------------------------------------------------

    /// @notice Settle every space's stream into `receiverBal`.
    function updateRevenue() public {
        for (uint256 i = 1; i <= NUM_SPACES; i++) {
            Space storage space = spaces[i];
            if (space.exists) _settle(space);
        }
    }

    /// @dev v1 bug: never zeroed `receiverBal`, so it could be claimed repeatedly until the contract
    ///      was drained of users' balances and escrows.
    function claimRevenue() external onlyOwner nonReentrant {
        updateRevenue();
        uint256 amount = receiverBal;
        receiverBal = 0;
        weth.safeTransfer(receiver, amount);
        emit RevenueClaimed(receiver, amount);
    }

    function setReceiver(address _receiver) external onlyOwner {
        if (_receiver == address(0)) revert ZeroAddress();
        updateRevenue();
        receiver = _receiver;
        emit ReceiverUpdated(_receiver);
    }

    // ------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------

    function getRemainingBalance(uint256 spaceId) public view returns (uint256) {
        Space storage space = spaces[spaceId];
        uint256 due = _due(space);
        return space.balance - due;
    }

    /// @notice Revenue accrued so far, including streams not yet settled.
    function getSubscriptionRevenue() external view returns (uint256 revenue) {
        revenue = receiverBal;
        for (uint256 i = 1; i <= NUM_SPACES; i++) {
            revenue += _due(spaces[i]);
        }
    }

    function getNftUri(uint256 spaceId) external view returns (string memory) {
        return spaces[spaceId].spaceUri;
    }

    /// @dev Off-chain helper; unbounded-looking but capped at NUM_SPACES.
    function getAllSpaces() external view returns (Space[] memory all) {
        all = new Space[](NUM_SPACES);
        for (uint256 i = 1; i <= NUM_SPACES; i++) {
            all[i - 1] = spaces[i];
        }
    }

    function getCurrentRemainingBalances() external view returns (uint256[] memory balances) {
        balances = new uint256[](NUM_SPACES);
        for (uint256 i = 1; i <= NUM_SPACES; i++) {
            balances[i - 1] = getRemainingBalance(i);
        }
    }

    // ------------------------------------------------------------------
    // Internal accounting
    // ------------------------------------------------------------------

    /// @dev Amount streamed since the last settlement, capped at the remaining balance.
    function _due(Space storage space) private view returns (uint256) {
        uint256 streamed = space.subscBurn * (block.timestamp - space.subscTime);
        return streamed < space.balance ? streamed : space.balance;
    }

    function _settle(Space storage space) private {
        uint256 due = _due(space);
        space.balance -= due;
        receiverBal += due;
        space.subscTime = block.timestamp;
    }

    function _reprice(Space storage space) private {
        space.subscBurn = (space.highestOffer * SUBSCRIBE_RATE) / (100 * 365 days);
    }

    /// @dev Clears the standing offer and returns the escrow owed back to the bidder.
    function _clearOffer(Space storage space) private returns (uint256 refund) {
        if (space.highestOfferer == address(0)) return 0;
        refund = space.highestOffer + space.subscOffer;
        space.highestOfferer = address(0);
        space.highestOffer = 0;
        space.subscOffer = 0;
    }
}
