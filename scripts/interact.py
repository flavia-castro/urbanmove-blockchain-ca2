# interact.py - reads information from the TaxiBooking contract on Ganache
# Usage: python scripts/interact.py
# Needs: Ganache open, the contract deployed, and TaxiBooking_abi.json in the same folder

import json
import os
from web3 import Web3

GANACHE_URL = "http://127.0.0.1:7545"
CONTRACT_ADDRESS = "0x6B108A05994aCD0836D9547c239448Ef5C2514Da"  # address shown in Remix after deploy

# 1. Connect to Ganache
w3 = Web3(Web3.HTTPProvider(GANACHE_URL))

if not w3.is_connected():
    print("ERROR: could not connect to Ganache. Is it open?")
    exit(1)

print("Connected to Ganache")
print("Chain ID:", w3.eth.chain_id)
print("Latest block:", w3.eth.block_number)

# 2. Load the contract ABI (the list of functions the contract has)
abi_path = os.path.join(os.path.dirname(__file__), "TaxiBooking_abi.json")
with open(abi_path) as f:
    abi = json.load(f)

contract = w3.eth.contract(address=Web3.to_checksum_address(CONTRACT_ADDRESS), abi=abi)

# 3. Read data from the contract (read-only calls, no gas, no MetaMask)
owner = contract.functions.owner().call()
fare = contract.functions.farePerKm().call()
next_id = contract.functions.nextRideId().call()
escrow = contract.functions.getContractBalance().call()

print("\n--- TaxiBooking contract ---")
print("Owner (UrbanMove):", owner)
print("Fare per km:", w3.from_wei(fare, "ether"), "ETH")
print("Rides created so far:", next_id)
print("ETH held in escrow:", w3.from_wei(escrow, "ether"), "ETH")

# 4. Show the details of each ride
status_names = ["Requested", "Accepted", "Started", "Completed", "Cancelled"]

for ride_id in range(next_id):
    ride = contract.functions.rides(ride_id).call()
    print(f"\nRide {ride_id}:")
    print("  Passenger:", ride[0])
    print("  Driver:", ride[1])
    print("  Distance:", ride[2], "km")
    print("  Amount held:", w3.from_wei(ride[3], "ether"), "ETH")
    print("  Status:", status_names[ride[5]])