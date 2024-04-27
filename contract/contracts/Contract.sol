// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/extension/LazyMint.sol";
import "@thirdweb-dev/contracts/extension/interface/IClaimableERC1155.sol";

contract NFTEvent is ERC1155Holder {
    struct Event {
        address organizer;
        string title;
        uint256 maxParticipants;
        uint256 registrationDeadline;
        address nftContract;
        uint256 tokenId;
        uint256 rewardTokenId;
        uint256 nftSupply; // Total supply 
        address[] participants;
        bool closed;
    }

    mapping(uint256 => Event) public events;
    uint256 public numberOfEvents = 0;

    IClaimableERC1155 public tokenContract; // token contract address

    // Event emitted when a participant registers for an event
    event ParticipantRegistered(uint256 indexed eventId, address indexed participant);

    // Event emitted when an event is closed
    event EventClosed(uint256 indexed eventId, address indexed organizer);

    constructor(address _tokenContract) {
        tokenContract = IClaimableERC1155(_tokenContract);
    }

    // Function to create an event
    function createEvent(
        string memory _title,
        uint256 _maxParticipants,
        uint256 _registrationDeadline,
        address _nftContract,
        uint256 _tokenId,
        uint256 _rewardTokenId,
        uint256 _nftSupply
    ) public returns (uint256) {
        require(_registrationDeadline > block.timestamp, "Registration deadline should be in the future.");
        require(_maxParticipants > 0, "Maximum participants should be greater than 0.");
        require(_nftSupply > 0, "NFT supply should be greater than 0.");
        require(_nftContract != address(0), "Invalid NFT contract address.");

        Event storage newEvent = events[numberOfEvents];
        newEvent.organizer = msg.sender;
        newEvent.title = _title;
        newEvent.maxParticipants = _maxParticipants;
        newEvent.registrationDeadline = _registrationDeadline;
        newEvent.nftContract = _nftContract;
        newEvent.tokenId = _tokenId;
        newEvent.rewardTokenId = _rewardTokenId;
        newEvent.nftSupply = _nftSupply;
        newEvent.closed = false;

        numberOfEvents++;

        return numberOfEvents - 1;
    }

    // Function to register for an event
    function registerForEvent(uint256 _eventId) public {
        Event storage eventToJoin = events[_eventId];
        require(!eventToJoin.closed, "Event registration closed.");
        require(eventToJoin.participants.length < eventToJoin.maxParticipants, "Maximum participants reached.");
        // Check if the sender owns the required NFT
        // require(
        //     IERC1155(eventToJoin.nftContract).balanceOf(msg.sender, eventToJoin.tokenId) > 0,
        //     "You must own the required NFT to register for this event."
        // );
        
        // Record participant registration
        eventToJoin.participants.push(msg.sender);
        emit ParticipantRegistered(_eventId, msg.sender);
    }

    // Function to check if a participant is registered for an event
    function isRegisteredForEvent(uint256 _eventId, address _participant) public view returns (bool) {
        Event storage eventToCheck = events[_eventId];
        for (uint256 i = 0; i < eventToCheck.participants.length; i++) {
            if (eventToCheck.participants[i] == _participant) {
                return true;
            }
        }
        return false;
    }

    // Function to close an event
    function closeEvent(uint256 _eventId) public {
        Event storage eventToClose = events[_eventId];
        require(eventToClose.organizer == msg.sender, "Only event organizer can close the event.");
        require(!eventToClose.closed, "Event already closed.");

        eventToClose.closed = true;
        emit EventClosed(_eventId, msg.sender);
    }

    // Function to claim tokens after event closure
    function claimTokens(uint256 _eventId) public payable {
        Event storage eventToClaim = events[_eventId];
        require(eventToClaim.closed, "Event must be closed to claim tokens.");
        require(isRegisteredForEvent(_eventId, msg.sender), "Not registered for this event.");
        uint256 tokenId = eventToClaim.rewardTokenId;

        tokenContract.claim(msg.sender, tokenId, 1);
    }

    // Function to get all participants of an event
    function getParticipants(uint256 _eventId) public view returns (address[] memory) {
        return events[_eventId].participants;
    }

    // Function to get details of all events
    function getAllEvents() public view returns (Event[] memory) {
        Event[] memory allEvents = new Event[](numberOfEvents);
        for (uint256 i = 0; i < numberOfEvents; i++) {
            allEvents[i] = events[i];
        }
        return allEvents;
    }

    
}
