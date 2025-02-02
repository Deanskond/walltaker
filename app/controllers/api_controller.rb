class ApiController < ApplicationController
  after_action :log_presence, only: %i[show_link]
  skip_before_action :verify_authenticity_token, only: :set_link_response

  # GET /api/links/:id.json
  def show_link
    @link = Link.find(params[:id])
    @set_by = User.find(@link.set_by_id) if @link.set_by_id
  rescue
    render json: { message: 'This link does not exist.' }, status: 404
  end

  # POST /api/links/:id/response.json
  def set_link_response
    params.permit(:type, :text)
    @link = Link.find(params[:id])
    valid = !@link.user.api_key.nil? && @link.user.api_key == params[:api_key]

    unless valid
      return render json: { message: 'Bad API key. Get an API key from your profile page on Walltaker.joi.how' }, status: 403
    end

    begin
      @link.response_type = params[:type].nil? ? "horny" : params[:type]
    rescue
      return render json: { message: 'type must be "horny", "disgust", or "came"' }, status: 400
    end

    @link.response_text = params[:text].nil? ? "" : params[:text]

    if @link.response_type == :disgust
      past_links = PastLink.where(link_id: @link.id, post_url: @link.post_url)
      past_links.destroy_all unless past_links.empty?

      last_past_link = PastLink.where(link_id: @link.id).where.not(post_url: @link.post_url).order('created_at').last

      @link.post_url = last_past_link ? last_past_link.post_url : nil
      @link.post_thumbnail_url = last_past_link ? last_past_link.post_thumbnail_url : nil
    end

    notification_text = "#{@link.user.username} loved your post!" if @link.response_type == 'horny'
    notification_text = "#{@link.user.username} did not like your post." if @link.response_type == 'disgust'
    notification_text = "#{@link.user.username} came to your post!" if @link.response_type == 'came'

    notification_text = "#{notification_text} \"#{@link.response_text}\"" unless @link.response_text.nil?

    Notification.create user_id: @link.set_by_id, notification_type: :post_response, text: notification_text, link: "/links/#{@link.id}"

    result = @link.save

    if result
      return render partial: 'link', locals: { link: @link }
    else
      return render json: { message: 'Bad request body, something with the response you sent looks malicious.' }, status: 400
    end
  rescue => e
    track :error, :api_link_missing_while_setting_response, id: params[:id], message: e.message
    return render json: { message: 'This link does not exist.', e: e }, status: 404
  end

  # GET /api/users/:username.json
  def show_user
    @user = User.find_by(username: params[:username])
    @has_friendship = Friendship.find_friendship(current_user, @user).exists? if current_user
    online_links = @user.link.where(friends_only: false).and(@user.link.where('expires > ?', Time.now).or(@user.link.where(never_expires: true))).and(@user.link.where('last_ping > ?', Time.now - 1.minute)) unless @has_friendship
    online_links = @user.link.where('expires > ?', Time.now).or(@user.link.where(never_expires: true)).and(@user.link.where('last_ping > ?', Time.now - 1.minute)) if @has_friendship

    @is_self = @user.id == current_user.id if current_user
    @is_self = false unless current_user
    @is_online = online_links.count > 0
    @public_links = @user.link if current_user
    @public_links = @user.link.where(friends_only: false).and(@user.link.where('expires > ?', Time.now).or(@user.link.where(never_expires: true))) unless current_user
  rescue => e
    track :error, :api_user_missing, username: params[:username], message: e.message
    render json: { message: 'This user does not exist.' }, status: 404
  end

  private

  def log_presence
    log_link_presence(@link)
  rescue => e
    track :error, :api_link_missing, id: params[:id], message: e.message
  end
end
