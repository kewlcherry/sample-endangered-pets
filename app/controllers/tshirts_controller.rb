class TshirtsController < ApplicationController
  def buy_tshirt
    @payment_method = PaymentMethod.new
  end

  def transparent_redirect_complete
    return if error_talking_to_core

    @payment_method = PaymentMethod.new(SpreedlyCore.get_payment_method(params[:token]))
    return render(action: :buy_tshirt) unless @payment_method.valid?

    response = SpreedlyCore.purchase(@payment_method, amount_to_charge, redirect_url: offsite_redirect_url, callback_url: offsite_callback_url)
    if response.code == 200
      return redirect_to(successful_purchase_url)
    elsif response.code == 202
      return redirect_to(response["transaction"]["checkout_url"])
    else
      set_flash_error(response)
      render(action: :buy_tshirt)
    end
  end

  def successful_purchase
  end

  def offsite_redirect
    @transaction = Transaction.new(SpreedlyCore.get_transaction(params[:transaction_token]))
    render text: "NICE"
  end

  def offsite_callback
    @@transactions_called_back ||= []
    @@transactions_called_back.concat(params[:transactions][:transaction].collect{|t| "#{t[:token]} for #{t[:amount]}: #{t[:message]}"})
    head :ok
  end

  def history
    @transactions = (defined?(@@transactions_called_back) ? @@transactions_called_back : [])
  end

  private

  def set_flash_error(response)
    if response["errors"]
      error = response["errors"].values.first
      error = error["__content__"] if error["__content__"]
      flash.now[:error] = error
    elsif response['transaction']
      r = response['transaction']['response'] || response['transaction']['setup_response']
      flash.now[:error] = "#{r['message']} #{r['error_detail']}"
    else
      flash.now[:error] = "Exception from backend"
      @error = response.body
    end
  end

  def error_talking_to_core
    return false if params[:error].blank?

    @payment_method = PaymentMethod.new
    flash.now[:error] = params[:error]
    render(action: :buy_tshirt)
    true
  end

  def amount_to_charge
    ((1.99 * @payment_method.how_many.to_i) * 100).to_i
  end
end
