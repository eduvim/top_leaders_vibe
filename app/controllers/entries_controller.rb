class EntriesController < ApplicationController
  def index
    @entries = repository.all.map { |stored| SituationEntry.from_h(stored) }
  end

  def new
    @entry = SituationEntry.new
  end

  def create
    @entry = SituationEntry.new(entry_params)
    @entry.status = draft_request? ? "draft" : "saved"

    if @entry.valid?
      persisted = repository.create(@entry.to_h)
      redirect_to entry_path(persisted["id"]),
                  notice: draft_request? ? t("situation_log.flash.draft_saved") : t("situation_log.flash.entry_saved")
    else
      render :new, status: :unprocessable_entity
    end
  rescue EntryRepository::StorageError
    # RF-05: keep the captured data on screen, never claim the entry was logged.
    flash.now[:alert] = t("situation_log.flash.save_failed")
    render :new, status: :service_unavailable
  end

  def show
    stored = repository.find(params[:id])
    if stored.nil?
      return render "errors/not_found", status: :not_found, layout: true
    end

    @entry = SituationEntry.from_h(stored)
  end

  def edit
    stored = repository.find(params[:id])
    if stored.nil?
      return render "errors/not_found", status: :not_found, layout: true
    end

    @entry = SituationEntry.from_h(stored)
  end

  def update
    stored = repository.find(params[:id])
    if stored.nil?
      return render "errors/not_found", status: :not_found, layout: true
    end

    @entry = SituationEntry.from_h(stored)
    @entry.assign_attributes(entry_params)
    @entry.status = draft_request? ? "draft" : "saved"

    if @entry.valid?
      repository.update(params[:id], @entry.to_h)
      redirect_to entry_path(params[:id]), notice: t("situation_log.flash.entry_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  rescue EntryRepository::StorageError
    # RF-05: never lose the original entry on a failed write.
    flash.now[:alert] = t("situation_log.flash.save_failed")
    render :edit, status: :service_unavailable
  end

  def destroy
    stored = repository.find(params[:id])
    if stored.nil?
      return render "errors/not_found", status: :not_found, layout: true
    end

    repository.destroy(params[:id])
    redirect_to entries_path, notice: t("situation_log.flash.entry_deleted")
  rescue EntryRepository::StorageError
    redirect_to entry_path(params[:id]), alert: t("situation_log.flash.delete_failed")
  end

  private

  def repository
    EntryRepository.new
  end

  def draft_request?
    params[:commit] == "draft"
  end

  def entry_params
    params.require(:entry).permit(:what_happened, :meaning, :emotion_raw, :intensity, :reaction)
  end
end
