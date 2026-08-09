class ReceiptsController < ApplicationController
  def index
    @receipts = Receipt.order(created_at: :desc)
  end

  def show
    @receipt = Receipt.find(params[:id])
  end

  def new
    @receipt = Receipt.new
  end

  def create
    @receipt = Receipt.new(receipt_params)

    if @receipt.save
      @receipt.image.open do |file|
        scanner = ReceiptScanner.new(file.path, content_type: @receipt.image.content_type)
        @receipt.update(scanner.extract)
      end
      redirect_to @receipt
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def receipt_params
    params.require(:receipt).permit(:image)
  end
end
