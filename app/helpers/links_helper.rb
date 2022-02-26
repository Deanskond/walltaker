module LinksHelper
  def link_id_for_decoration(link_id)
    return '🐇' if link_id == 69
    return '🐕' if link_id == 1

    link_id
  end

  def link_agent_to_icon(link_agent)
    return :unknown if link_agent.nil?
    return :desktop if link_agent.include? 'Walltaker Go Client/'
    return :android if link_agent.include? 'walltaker-android-client/'
    return :joihow if link_agent.include? 'joihow'

    :unknown
  end
end
