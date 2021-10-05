import NonFungibleToken from "NonFungibleToken.cdc"

pub contract interface NFTPlus {

    pub fun receiver(_ address: Address): Capability<&{NonFungibleToken.Receiver}>
    pub fun collectionPublic(_ address: Address): Capability<&{NonFungibleToken.CollectionPublic}>

    pub struct Royalties {
        pub let address: Address
        pub let fee: UFix64
    }

    pub resource interface WithRoyalties {
        pub fun getRoyalties(): [Royalties]
    }

    pub resource NFT: NonFungibleToken.INFT, WithRoyalties {
        pub let id: UInt64
        pub fun getRoyalties(): [Royalties]
    }

    pub resource interface CollectionPublic {
        pub fun getRoyalties(id: UInt64): [Royalties]
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun getRoyalties(id: UInt64): [Royalties]
    }

}
