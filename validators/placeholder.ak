use aiken/collection/list
use cardano/address.{Address, VerificationKey}
use cardano/assets
use cardano/transaction.{Output, OutputReference, Transaction}

pub type SwapDatum {
  owner: ByteArray,
  lock_amount: Int,
  want_amount: Int,
}

pub type SwapRedeemer {
  Cancel
  Swap
}

validator swap_ada {
  spend(
    datum_opt: Option<SwapDatum>,
    redeemer: SwapRedeemer,
    _utxo: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = datum_opt

    when redeemer is {
      Cancel -> {
        let seller_signed = list.has(self.extra_signatories, datum.owner)?

        let refunded =
          self.outputs
            |> list.any(
                fn(o) {
                  when o.address.payment_credential is {
                    VerificationKey(pkh) ->
                      pkh == datum.owner && assets.lovelace_of(o.value) >= datum.lock_amount
                    _ -> False
                  }
                },
              )
        seller_signed && refunded
      }

      Swap -> {
        expect Some(fulfiller) = list.head(self.extra_signatories)
        expect fulfiller != datum.owner

        let seller_received =
          self.outputs
            |> list.any(
                fn(o) {
                  when o.address.payment_credential is {
                    VerificationKey(pkh) ->
                      pkh == datum.owner && assets.lovelace_of(o.value) >= datum.want_amount
                    _ -> False
                  }
                },
              )

        let fulfiller_received =
          self.outputs
            |> list.any(
                fn(o) {
                  when o.address.payment_credential is {
                    VerificationKey(pkh) ->
                      pkh == fulfiller && assets.lovelace_of(o.value) >= datum.lock_amount
                    _ -> False
                  }
                },
              )

        seller_received && fulfiller_received
      }
    }
  }

  else(_ctx: Data) {
    False
  }
}
