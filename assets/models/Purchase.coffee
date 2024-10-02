APP = window.APP
APP.Models.factory('Purchase', ['$resource', ($resource) ->
  Purchase = $resource(
    APIURL + '/purchase',
    {},
    {
      adminIndex:  { method: 'GET',    url: APIURL + '/admin/purchase/index', isArray: true }
      byUserId:    { method: 'GET',    url: APIURL + '/purchase/byUserId/:userId', isArray: true }
      byInvoiceNumberPublic:    { method: 'GET',    url: APIURL + '/purchase/byInvoiceNumberPublic/:invoiceNumber', isArray: false }
      read:        { method: 'GET',    url: APIURL + '/purchase/:id' }
      commissions: { method: 'PUT',    url: APIURL + '/admin/purchase/commissions' }
      markCommPaid: { method: 'PUT',   url: APIURL + '/admin/purchase/commissions/markaspaid' }
      paypal:       { method: 'PUT',   url: APIURL + '/admin/purchase/commissions/paypal', isArray: true }
      sendConfirmations: { method: 'PUT',    url: APIURL + '/admin/purchase/confirmations/send' }
      recordPayment: { method: 'PUT',    url: APIURL + '/admin/purchase/payment/record' }
    }
  )

  return Purchase;
])
