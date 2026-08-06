module Dte
  # Resultado uniforme de cualquier proveedor de emision.
  #
  # `status` usa los mismos nombres que Sale.sii_statuses para que el emisor no
  # tenga que traducir por proveedor.
  Receipt = Struct.new(:status, :folio, :track_id, :raw, keyword_init: true)
end
