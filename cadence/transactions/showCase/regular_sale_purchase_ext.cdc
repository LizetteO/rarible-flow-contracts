/**
 * Create regular sale on signer account for flow
 * Account must be initialized with ShowCase
 *
 * @param sellerAddress: seller address
 * @param tokenId: NFT id for sale
 * @param amount: NFT price in flow
 */
import RegularSaleOrder from 0xREGULARSALEORDER
import NonFungibleToken from 0xNONFUNGIBLETOKEN
import FungibleToken from 0xFUNGIBLETOKEN
import StoreShowCase from 0xSTORESHOWCASE
import AssetBound from 0xASSETBOUND
import FlowToken from 0xFLOWTOKEN
import FtPathMapper from 0xFTPATHMAPPER
import NFTProvider from 0xNFTPROVIDER
import SaleOrder from 0xSALEORDER
import CommonNFT from 0xCOMMONNFT

transaction(sellerAddress: Address, saleId: UInt64) {

    let showCase: &{StoreShowCase.ShowCasePublic}
    let receiver: &{NonFungibleToken.CollectionPublic}
    let vault: @FungibleToken.Vault

    prepare(signer: AuthAccount) {
        if !signer.getCapability<&{NonFungibleToken.CollectionPublic}>(/public/NFTCollection).check() {
            let collection <- NFTProvider.createEmptyCollection()
            signer.save<@NonFungibleToken.Collection>(<-collection, to: /storage/NFTCollection)
            signer.link<&{NonFungibleToken.CollectionPublic}>(/public/NFTCollection, target: /storage/NFTCollection)
        }

        let seller = getAccount(sellerAddress)
        self.showCase = seller.getCapability<&{StoreShowCase.ShowCasePublic}>(StoreShowCase.storeShowCasePublicPath).borrow()
            ?? panic("Could not borrow showCase reference")
        // self.receiver = signer.getCapability<&{NonFungibleToken.CollectionPublic}>(/public/NFTCollection).borrow()
        self.receiver = CommonNFT.collectionPublic(signer.address).borrow()
            ?? panic("Could not borrow receiver reference")

        let provider = signer.borrow<&{FungibleToken.Provider}>(from: FtPathMapper.storage[Type<&FlowToken.Vault>().identifier]!)!
        let orderRef = self.showCase.borrow(id: saleId) as! &RegularSaleOrder.Order
        let amount = orderRef.bid.amount + orderRef.bid.amount * orderRef.fee.buyerFee / 100.0
        self.vault <- provider.withdraw(amount: amount)

    }

    execute {
        let item <- self.showCase.close(id: saleId, item: <- self.vault)!
        let product <- item as! @NonFungibleToken.NFT
        self.receiver.deposit(token: <- product)
    }
}
