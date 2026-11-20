// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Taxi Booking with escrow payments
contract TaxiBooking {

    // ---------- Types ----------
    enum RideStatus { Requested, Accepted, Started, Completed, Cancelled }

    struct Ride {
        address passenger;          // who requested the ride
        address driver;             // who is the driver
        uint256 distanceKm;         // trip distance in km
        uint256 amountPaid;         // money held by the contract (wei)
        bytes32 routeHash;          // hash of pickup and drop-off locations
        RideStatus status;          // current state of the ride
    }

    // ---------- State variables ----------
    address public owner;           // UrbanMove company (registers drivers)
    uint256 public farePerKm;       // price in wei
    uint256 public nextRideId;      // counter for ride IDs
    mapping(uint256 => Ride) public rides;
    mapping(address => bool) public verifiedDrivers;

    // ---------- Events ----------
    event DriverRegistered(
        address indexed driver
    );

    event RideRequested(
        uint256 indexed rideId,
        address indexed passenger,
        uint256 distanceKm,
        uint256 amountPaid
    );

    event RideAccepted(
        uint256 indexed rideId,
        address indexed driver
    );

    event RideStarted(
        uint256 indexed rideId
    );

    event RideCompleted(
        uint256 indexed rideId,
        address indexed driver,
        uint256 amountReleased
    );

    event RideCancelled(
        uint256 indexed rideId,
        address indexed passenger,
        uint256 refundAmount
    );

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }

    modifier onlyVerifiedDriver() {
        require(verifiedDrivers[msg.sender], "Only verified drivers");
        _;
    }

    modifier rideExists(uint256 _rideId) {
        require(rides[_rideId].passenger != address(0), "Ride does not exist");
        _;
    }

    // ---------- Constructor ----------
    constructor(uint256 _farePerKm) {
        owner = msg.sender;
        farePerKm = _farePerKm;
    }

    // ---------- Helper: hash route data ----------
    function hashRoute(string memory _pickup, string memory _dropoff)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_pickup, _dropoff));
    }

    // ---------- View: ETH currently held in escrow ----------
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ---------- Owner: register a verified driver ----------
    function registerDriver(address _driver)
        external
        onlyOwner
    {
        require(_driver != address(0), "Invalid driver address");
        verifiedDrivers[_driver] = true;
        emit DriverRegistered(_driver);
    }

    // ---------- Passenger: request a ride ----------
    function requestRide(uint256 _distanceKm, bytes32 _routeHash)
        external
        payable
        returns (uint256)
    {
        require(msg.sender != owner, "Owner cannot request a ride");
        require(_distanceKm > 0, "Distance must be greater than zero");
        require(msg.value == farePerKm * _distanceKm, "Incorrect payment amount");

        uint256 rideId = nextRideId;

        rides[rideId] = Ride({
            passenger: msg.sender,
            driver: address(0),
            distanceKm: _distanceKm,
            amountPaid: msg.value,
            routeHash: _routeHash,
            status: RideStatus.Requested
        });

        nextRideId++;

        emit RideRequested(rideId, msg.sender, _distanceKm, msg.value);
        return rideId;
    }

    // ---------- Driver: accept a ride ----------
    function acceptRide(uint256 _rideId)
        external
        onlyVerifiedDriver
        rideExists(_rideId)
    {
        Ride storage ride = rides[_rideId];
        require(ride.status == RideStatus.Requested, "Ride is not available");
        require(msg.sender != ride.passenger, "Passenger cannot accept own ride");

        ride.driver = msg.sender;
        ride.status = RideStatus.Accepted;

        emit RideAccepted(_rideId, msg.sender);
    }

    // ---------- Driver: start the ride ----------
    function startRide(uint256 _rideId)
        external
        rideExists(_rideId)
    {
        Ride storage ride = rides[_rideId];
        require(msg.sender == ride.driver, "Only the assigned driver");
        require(ride.status == RideStatus.Accepted, "Ride must be accepted first");

        ride.status = RideStatus.Started;

        emit RideStarted(_rideId);
    }

    // ---------- Driver: complete the ride and receive payment ----------
    function completeRide(uint256 _rideId)
        external
        rideExists(_rideId)
    {
        Ride storage ride = rides[_rideId];
        require(msg.sender == ride.driver, "Only the assigned driver");
        require(ride.status == RideStatus.Started, "Ride has not started");

        uint256 amount = ride.amountPaid;

        // Update state BEFORE sending money (security)
        ride.status = RideStatus.Completed;
        ride.amountPaid = 0;

        (bool sent, ) = payable(ride.driver).call{value: amount}("");
        require(sent, "Payment to driver failed");

        emit RideCompleted(_rideId, ride.driver, amount);
    }

    // ---------- Passenger: cancel before a driver accepts ----------
    function cancelRide(uint256 _rideId)
        external
        rideExists(_rideId)
    {
        Ride storage ride = rides[_rideId];
        require(msg.sender == ride.passenger, "Only the passenger can cancel");
        require(ride.status == RideStatus.Requested, "Ride can no longer be cancelled");

        uint256 refund = ride.amountPaid;

        // Update state BEFORE sending money (security)
        ride.status = RideStatus.Cancelled;
        ride.amountPaid = 0;

        (bool refunded, ) = payable(ride.passenger).call{value: refund}("");
        require(refunded, "Refund to passenger failed");

        emit RideCancelled(_rideId, ride.passenger, refund);
    }
}