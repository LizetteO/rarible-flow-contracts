import NonFungibleToken from 0xNONFUNGIBLETOKEN
import NFTPlus from 0xNFTPLUS

pub contract CommonNFTDraft : NonFungibleToken, NFTPlus {
    pub var totalSupply: UInt64

    pub var draftProviderPath: PublicPath
    pub var collectionPublicPath: PublicPath
    pub var collectionStoragePath: StoragePath
    pub var minterPublicPath: PublicPath
    pub var minterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event Draft(id: UInt64, collection: String, creator: Address, royalties: [NFTPlus.Royalties])
    pub event Mint(id: UInt64, collection: String, creator: Address, royalties: [NFTPlus.Royalties])
    pub event Destroy(id: UInt64)
    pub event Transfer(id: UInt64, from: Address?, to: Address)

    pub struct Royalties {
        pub let address: Address
        pub let fee: UFix64

        init(address: Address, fee: UFix64) {
            self.address = address
            self.fee = fee
        }
    }

    pub resource NFT: NonFungibleToken.INFT, NFTPlus.WithRoyalties {
        pub let id: UInt64
        pub let creator: Address
        pub let royalties: [NFTPlus.Royalties]

        init(id: UInt64, creator: Address, royalties: [NFTPlus.Royalties]) {
            self.id = id
            self.creator = creator
            self.royalties = royalties
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface DraftProvider {
        access(account) fun take(tokenId: UInt64): @NFT
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, NFTPlus.Transferable, DraftProvider {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        access(account) fun take(tokenId: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: tokenId) ?? panic("Missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- (token as! @NFT)
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @NFT
            let id: UInt64 = token.id
            let dummy <- self.ownedNFTs[id] <- token
            destroy dummy
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun transfer(tokenId: UInt64, to: Capability<&{NonFungibleToken.Receiver}>) {
            let token <- self.ownedNFTs.remove(key: tokenId) ?? panic("Missed NFT")
            emit Withdraw(id: tokenId, from: self.owner?.address)
            to.borrow()!.deposit(token: <- token)
            emit Transfer(id: tokenId, from: self.owner?.address, to: to.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }
    
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource Minter {
        pub fun mint(creator: Capability<&{NonFungibleToken.Receiver}>, royalties: [NFTPlus.Royalties]): &NonFungibleToken.NFT {
            let receiver = creator.borrow() ?? panic("Could not borrow draft receiver reference")
            let token <- create NFT(
                id: CommonNFTDraft.totalSupply,
                creator: creator.address,
                royalties: royalties
            )
            CommonNFTDraft.totalSupply = CommonNFTDraft.totalSupply + 1
            let tokenRef = &token as &NonFungibleToken.NFT
            emit Mint(id: token.id, collection: token.getType().identifier, creator: creator.address, royalties: royalties)
            receiver.deposit(token: <- token)
            return tokenRef
        }

        // pub fun mint2(creator: Capability<&{NonFungibleToken.Receiver})>, tokenId, metadata: String): &NonFungibleToken.NFT {
            // let receiver = creator.borrow() ?? panic("Could not borrow draft receiver reference")
            // let draft <- CommonNFTDraft.draftProvider(creator.address).borrow()!.take(tokenId: tokenId)
            // let token <- create
        // }
    }

    pub fun configureAccount(_ account: AuthAccount): &Collection {
        let collection <- self.createEmptyCollection() as! @Collection
        let ref = &collection as &Collection
        account.save(<- collection, to: self.collectionStoragePath)
        account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(self.collectionPublicPath, target: self.collectionStoragePath)
        return ref
    }

    pub fun cleanAccount(_ account: AuthAccount) {
        account.unlink(self.collectionPublicPath)
        destroy <- account.load<@Collection>(from: self.collectionStoragePath)
    }

    pub fun collectionRef(_ account: AuthAccount): &Collection {
        return account.borrow<&Collection>(from: self.collectionStoragePath) ?? self.configureAccount(account)
    }

    pub fun receiver(_ address: Address): Capability<&{NonFungibleToken.Receiver}> {
        return getAccount(address).getCapability<&{NonFungibleToken.Receiver}>(self.collectionPublicPath)
    }

    pub fun collectionPublic(_ address: Address): Capability<&{NonFungibleToken.CollectionPublic}> {
        return getAccount(address).getCapability<&{NonFungibleToken.CollectionPublic}>(self.collectionPublicPath)
    }

    access(account) fun draftProvider(_ address: Address): Capability<&{DraftProvider}> {
        return getAccount(address).getCapability<&{DraftProvider}>(self.draftProviderPath)
    }

    pub fun minter(): Capability<&Minter> {
        return self.account.getCapability<&Minter>(self.minterPublicPath)
    }

    pub fun deinit(_ account: AuthAccount) {
        account.unlink(self.minterPublicPath)
        destroy <- account.load<@AnyResource>(from: self.minterStoragePath)

        account.unlink(self.collectionPublicPath)
        destroy <- account.load<@AnyResource>(from: self.collectionStoragePath)
    }

    init() {
        self.totalSupply = 1

        self.draftProviderPath = /public/CommonNFTDraftProvider
        self.collectionPublicPath = /public/CommonNFTDraftCollection
        self.collectionStoragePath = /storage/CommonNFTDraftCollection
        self.minterPublicPath = /public/CommonNFTDraftMinter
        self.minterStoragePath = /storage/CommonNFTDraftMinter

        let minter <- create Minter()
        self.account.save(<- minter, to: self.minterStoragePath)
        self.account.link<&Minter>(self.minterPublicPath, target: self.minterStoragePath)

        let collection <- self.createEmptyCollection()
        self.account.save(<- collection, to: self.collectionStoragePath)
        self.account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(self.collectionPublicPath, target: self.collectionStoragePath)
        self.account.link<&{DraftProvider}>(self.draftProviderPath, target: self.collectionStoragePath)

        emit ContractInitialized()
    }
}
