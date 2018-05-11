pragma solidity ^0.4.17;
contract RideRequest {
    
    //////////////////////// NOTES /////////////////////////////////////////////
    // It would be ideal to use structs, but currently tuples are not supported
    // in public calls :,(
    // struct Requester {
    //     address requesterAddress;
    //     Coordinate location;
    // }
    
    // struct DriverOffer {
    //     address driverAddress;
    //     Coordinate location;
    // }
    
    enum State { CREATED, ACCEPTED, STARTED, COMPLETED, CANCELLED, REFUNDED }
    
    struct Coordinate {
        int latitude;
        uint latitudeDecimal;
        int longitude;
        uint longitudeDecimal;
    }
    
    // Destination Coordinates
    Coordinate public destination;
    
    // Requester
    address public requester;
    Coordinate public requesterLocation;
    string public requesterPhoneNumber;
    
    // Selected drive offer
    address public driver;
    Coordinate public driverLocation;
    string public driverPhoneNumber;
    
    // Available drive offers
    address[] public possibleDrivers;
    mapping (address => Coordinate) public possibleDriversLocations;
    mapping (address => string) public possibleDriversPhoneNumbers;

    // Payment
    uint public preTripPayment;
    uint public postTripPayment;
    
    // State of contract
    State public state;
    
    uint MAX_OFFERS = 5; 
    uint NOT_AN_OFFER = 9999;

    constructor(uint _prePayment, uint _postPayment, string _phoneNumber, 
                int _curLatitude, uint _curLatitudeDecimal,int _curLongitude, 
                uint _curLongitudeDecimal, int _destLatitude, 
                uint _destLatitudeDecimal, int _destLongitude, 
                uint _destLongitudeDecimal) public payable {
        require(_prePayment + _postPayment == msg.value);
        preTripPayment = _prePayment;
        postTripPayment = _postPayment;
        requesterPhoneNumber = _phoneNumber;
                    
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude,
            latitudeDecimal: _curLatitudeDecimal,
            longitude: _curLongitude,
            longitudeDecimal: _curLongitudeDecimal
        });
        
        requester = msg.sender;
        requesterLocation = curLocation;
        
        destination = Coordinate({
            latitude: _destLatitude,
            latitudeDecimal: _destLatitudeDecimal,
            longitude: _destLongitude,
            longitudeDecimal: _destLongitudeDecimal
        });
    
        state = State.CREATED;
    }
    
    //////////////////////////////
    //// Requester Functions ////
    ////////////////////////////
    
    /**
     * Called by the requester to signify the ride has been COMPLETED,
     * and unlocks post payment for the driver.
     */
    function completeRide() public requesterAccess {
        require(state == State.STARTED);
        state = State.COMPLETED;
    }
    
    /**
     * Called by the requester to start the ride when in the driver's car, 
     * gives the driver the pre-payment and locks the post payment
     * NOTE: Only a refund can given the requester his payment back from here.
     */
    function startRide() public requesterAccess {
        require(state == State.ACCEPTED);
        // Give the driver the pre-payment for pickup
        driver.transfer(preTripPayment);
        state = State.STARTED;
    }
    
    /**
     * Called by the requester to accept a driver offer.
     */
    function acceptDriverOffer(uint _driverChoice) public requesterAccess {
        address driverAddress = possibleDrivers[_driverChoice];
        require(isDriver(driverAddress) && state == State.CREATED);
        driver = possibleDrivers[_driverChoice];
        driverLocation = possibleDriversLocations[driverAddress];
        driverPhoneNumber = possibleDriversPhoneNumbers[driverAddress];
        state = State.ACCEPTED;
    }
    
    /**
     * Called by ride requester before an offer is ACCEPTED to cancel the 
     * request and refund all ether OR when the request has been REFUNDED by
     * the driver.
     */
    function cancelRequest() public requesterAccess {
        require(state == State.CREATED || state == State.REFUNDED);
        selfdestruct(requester);
    }
    
    
    //////////////////////////////
    ///// Driver Functions //////
    ////////////////////////////
    
    /**
     * While contract is in the CREATED state, a driver can create 
     * a drive offer with their phone number and current location.
     */
    function createDriveOffer(string _phoneNumber, int _curLatitude, 
                              uint _curLatitudeDecimal, int _curLongitude, 
                              uint _curLongitudeDecimal) public {
        require(possibleDrivers.length < MAX_OFFERS 
                && !isDriver(msg.sender) 
                && state == State.CREATED);
        
        Coordinate memory curLocation = Coordinate({
            latitude: _curLatitude,
            latitudeDecimal: _curLatitudeDecimal,
            longitude: _curLongitude,
            longitudeDecimal: _curLongitudeDecimal
        });
        
        possibleDrivers.push(msg.sender);
        possibleDriversLocations[msg.sender] = curLocation;
        possibleDriversPhoneNumbers[msg.sender] = _phoneNumber;
    }
    
    /**
     * Called by a driver who has made an offer that has yet to be STARTED
     * removes offer from offer list.
     */
    function cancelDriveOffer() public {
        require(state == State.CREATED);
        uint indexOfOffer = findDriveOffer(msg.sender);
        if (indexOfOffer != NOT_AN_OFFER) {
            removeDriveOffer(indexOfOffer);
        }
    }
    
    /**
     * Called by the driver when he is unable to fufill the contract.
     * Refunds the requester.
     */
    function refundRequest() public driverAccess {
        state = State.REFUNDED;
    }
    
    /**
     * Called by the driver when the ride is COMPLETED, withdrawing remaining
     * ETH from contract.
     */
    function recievePayment() public driverAccess {
        require(state == State.COMPLETED);
        selfdestruct(driver);
    }
    
    ///////////////////////////////////
    //// Private Helper Functions ////
    /////////////////////////////////
    
    /**
     * Checks if given address has a drive offer in the drive offer list
     */
    function isDriver(address _driverAddress) private view returns(bool) {
        bool isADriver = false;
        uint indexOfOffer = findDriveOffer(_driverAddress);
        if (indexOfOffer != NOT_AN_OFFER) {
            isADriver = true;
        }
        return isADriver;
    }
    
    /**
     * Find the driver offer in the possibleDriver list 
     * or return NOT_AN_OFFER (== 9999)
     */
    function findDriveOffer(address _driverAddress) private view returns(uint) {
        for (uint i; i < possibleDrivers.length; i++) {
            if (possibleDrivers[i] == _driverAddress) {
                return i;
            }
        }
        return NOT_AN_OFFER;
    }
    
    /**
     * Remove driver offer from the possibleDrivers list
     */
    function removeDriveOffer(uint index) private {
        require(index < possibleDrivers.length);
        for (uint i = index; i<possibleDrivers.length-1; i++){
            possibleDrivers[i] = possibleDrivers[i+1];
        }
        possibleDrivers.length--;
    }
    
    //////////////////////////////
    //////// Modifiers //////////
    ////////////////////////////
    
    modifier requesterAccess {
        require(msg.sender == requester);
        _;
    }
    
    modifier driverAccess {
        require(msg.sender == driver);
        _;
    }
    
}