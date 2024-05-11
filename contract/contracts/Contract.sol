// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@thirdweb-dev/contracts/extension/LazyMint.sol";
import "@thirdweb-dev/contracts/extension/interface/IClaimableERC1155.sol";

contract NFTEvent is ERC1155Holder {
    struct Event {
        uint256 eventId;
        address organizer;
        string title;
        uint256 maxParticipants;
        uint256 registrationDeadline;
        address[] cardContracts;
        uint256 rewardTokenId;
        address[] shortList;
        address[] participants;
        bool closed;
        string image;
    }

    struct EventWithJoined {
        uint256 eventId;
        address organizer;
        string title;
        uint256 maxParticipants;
        uint256 registrationDeadline;
        address[] cardContracts;
        uint256 rewardTokenId;
        address[] shortList;
        address[] participants;
        bool closed;
        string image;
        bool isJoined;
    }

    mapping(uint256 => Event) public events;
    uint256 public numberOfEvents;

    IClaimableERC1155 public tokenContract; // Reward Token contract address

    event ParticipantRegistered(
        uint256 indexed eventId,
        address indexed participant
    );
    event EventClosed(uint256 indexed eventId, address indexed organizer);

    constructor() {
        tokenContract = IClaimableERC1155(
            0xD1a1C627A7Cd077DcEB64cD767E9e03362071AEB
        );
        numberOfEvents = 0;
    }

    function createEvent(
        string memory _title,
        uint256 _maxParticipants,
        uint256 _registrationDeadline,
        address[] memory _cardContracts,
        uint256 _rewardTokenId,
        string memory _image
    ) public returns (uint256) {
        require(
            _registrationDeadline > block.timestamp,
            "Registration deadline should be in the future."
        );
        require(
            _maxParticipants > 0,
            "Maximum participants should be greater than 0."
        );

        Event storage newEvent = events[numberOfEvents];
        newEvent.eventId = numberOfEvents;
        newEvent.organizer = msg.sender;
        newEvent.title = _title;
        newEvent.maxParticipants = _maxParticipants;
        newEvent.registrationDeadline = _registrationDeadline;
        newEvent.cardContracts = _cardContracts;
        newEvent.rewardTokenId = _rewardTokenId;
        newEvent.closed = false;
        newEvent.image = _image;

        numberOfEvents++;

        return numberOfEvents;
    }

    // Function to check if a participant is registered for an event
    function isRegisteredForEvent(
        uint256 _eventId,
        address _sender
    ) public view returns (bool) {
        Event storage eventToCheck = events[_eventId];
        for (uint256 i = 0; i < eventToCheck.shortList.length; i++) {
            if (eventToCheck.shortList[i] == _sender) {
                return true;
            }
        }
        return false;
    }

    //Function to check if a participant is joined for an event
    function isJoinedForEvent(
        uint256 _eventId,
        address _sender
    ) public view returns (bool) {
        Event storage eventToCheck = events[_eventId];
        for (uint256 i = 0; i < eventToCheck.participants.length; i++) {
            if (eventToCheck.participants[i] == _sender) {
                return true;
            }
        }
        return false;
    }

    function registerForEvent(
        uint256 _eventId,
        address _cardContract,
        uint256 _tokenId,
        address _sender
    ) public {
        Event storage eventToJoin = events[_eventId];
        require(!eventToJoin.closed, "Event registration closed.");
        require(
            !isRegisteredForEvent(_eventId, _sender),
            "Already registered for this event."
        );
        require(
            eventToJoin.shortList.length < eventToJoin.maxParticipants,
            "Maximum participants reached."
        );
        require(
            eventToJoin.participants.length < eventToJoin.maxParticipants,
            "Maximum participants reached."
        );

        bool isCardContractValid = false;

        address[] storage cardContracts = eventToJoin.cardContracts;
        for (uint256 i = 0; i < cardContracts.length; i++) {
            if (cardContracts[i] == _cardContract) {
                isCardContractValid = true;
                break;
            }
        }
        require(isCardContractValid, "Invalid NFT card contract.");

        if (
            isCardContractValid &&
            IERC1155(_cardContract).balanceOf(_sender, _tokenId) > 0
        ) {
            eventToJoin.shortList.push(_sender);
            emit ParticipantRegistered(_eventId, _sender);
        } else {
            revert("Invalid NFT card or token ID.");
        }
    }

    //Function to join event after registered
    function joinEvent(uint256 _eventId) public {
        Event storage eventToJoin = events[_eventId];
        require(
            eventToJoin.participants.length < eventToJoin.maxParticipants,
            "Maximum participants reached."
        );
        require(!eventToJoin.closed, "Event registration closed.");
        require(
            isRegisteredForEvent(_eventId, msg.sender),
            "Not registered for this event."
        );
        require(
            !isJoinedForEvent(_eventId, msg.sender),
            "Already joined for this event."
        );
        eventToJoin.participants.push(msg.sender);
    }

    // Function to close an event
    function closeEvent(uint256 _eventId) public returns (address[] memory) {
        Event storage eventToClose = events[_eventId];
        require(
            eventToClose.organizer == msg.sender,
            "Only event organizer can close the event."
        );
        require(!eventToClose.closed, "Event already closed.");

        eventToClose.closed = true;
        emit EventClosed(_eventId, msg.sender);
        return eventToClose.participants;
    }

    // // Function to claim tokens after event closure
    // function claimTokens(uint256 _eventId) public payable {
    //     Event storage eventToClaim = events[_eventId];
    //     require(eventToClaim.closed, "Event must be closed to claim tokens.");
    //     require(isRegisteredForEvent(_eventId, msg.sender), "Not registered for this event.");
    //     uint256 tokenId = eventToClaim.rewardTokenId;

    //     tokenContract.claim(msg.sender, tokenId, 1);
    // }

    // Function to get all participants of an event
    function getParticipants(
        uint256 _eventId
    ) public view returns (address[] memory) {
        return events[_eventId].participants;
    }

    function getEventById(uint256 _eventId) public view returns (Event memory) {
        return events[_eventId];
    }

    // Function to get details of all events
    function getAllEvents() public view returns (Event[] memory) {
        // Create an array to store all events
        Event[] memory allEvents = new Event[](numberOfEvents);
        uint256 i = 0;
        for (uint256 j = 0; j < numberOfEvents; j++) {
            allEvents[i] = events[j];
            i++;
        }
        return allEvents;
    }

    function getRegisteredEvents(
        address _sender
    ) public view returns (EventWithJoined[] memory) {
        uint256 count = 0;
        // Count how many events the participant has joined
        for (uint256 i = 0; i < numberOfEvents; i++) {
            if (isRegisteredForEvent(i, _sender)) {
                count++;
            }
        }

        // Create an array to store the participant's joined events
        EventWithJoined[] memory joinedEvents = new EventWithJoined[](count);
        uint256 index = 0;

        // Populate the array with the participant's joined events
        for (uint256 i = 0; i < numberOfEvents; i++) {
            if (isRegisteredForEvent(i, _sender)) {
                Event storage eventToCheck = events[i];
                bool isUserJoined = isJoinedForEvent(i, _sender);

                // Create a new Event instance with the additional isJoined flag
                joinedEvents[index] = EventWithJoined({
                    eventId: eventToCheck.eventId,
                    organizer: eventToCheck.organizer,
                    title: eventToCheck.title,
                    maxParticipants: eventToCheck.maxParticipants,
                    registrationDeadline: eventToCheck.registrationDeadline,
                    cardContracts: eventToCheck.cardContracts,
                    rewardTokenId: eventToCheck.rewardTokenId,
                    shortList: eventToCheck.shortList,
                    participants: eventToCheck.participants,
                    closed: eventToCheck.closed,
                    image: eventToCheck.image,
                    isJoined: isUserJoined
                });
                index++;
            }
        }

        return joinedEvents;
    }
}
