import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import MotoGPPack from "../contracts/MotoGPPack.cdc"

pub fun main(address: Address, tokenId: UInt64): &AnyResource {
    let account = getAccount(address)
    let collection = getAccount(address).getCapability<&{MotoGPPack.IPackCollectionPublic}>(/public/motogpPackCollection).borrow()!
    return collection.borrowNFT(id: tokenId)
}
