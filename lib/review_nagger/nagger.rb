class Nagger
  ICONS = { robot: '🤖', art: '🎨' }
  JIRA_REGEX = /([A-Z]*-[0-9]*)(:|\ )/
  NO_REVIEWS_MESSAGE = '@here No pending reviews! 💋 💋 💋'

  def initialize
    @gitlab = GitLab.new

    @slack = Slack::Web::Client.new
    @slack.auth_test
  end

  def run!
    todo = get_todo(get_merge_requests)
    message = get_message(todo)

    $stdout << "Notifying #%s about pending reviews\n" % [
      AppConfig::SLACK_CHANNEL
    ]

    unless ARGV.include?('-d')
      notify_slack!(message)
    end
  rescue GitLab::ProjectNotFound
    $stderr << "GitLab project not found, check your access token!\n"
    exit 1
  end

  def get_merge_requests
    merge_requests = @gitlab.filtered_merge_requests
    return [] if !merge_requests || !merge_requests.any?
    merge_requests
  end

  def jira_handle(title)
    title.match(JIRA_REGEX)[1]
  rescue
  end

  def get_todo(merge_requests)
    todo = []

    merge_requests.each do |merge_request|
      todo << {
        title: merge_request['title'],
        url: merge_request['web_url'],
        missing: @gitlab.missing_reviews(merge_request),
        jira: jira_handle(merge_request['title'])
      }
    end

    todo
  end

  def todo_of_type(todo, type)
    todo.select { |t| t[:missing].include?(type) }
  end

  def format_todo(todo)
    todo.map { |t| t[:url] + ' (%s)' % t[:jira] }.join($/)
  end

  def get_message(todo)
    return NO_REVIEWS_MESSAGE if todo.empty?

    message = '@here *TODOs*'

    %w[robot art].each do |type|
      next unless todo_of_type(todo, type).any?

      message << $/ + ICONS[type.to_sym] + $/
      message << format_todo(todo_of_type(todo, type))
    end

    message
  end

  def notify_slack!(message)
    @slack.chat_postMessage \
      channel: '#%s' % AppConfig::SLACK_CHANNEL,
      text: message,
      as_user: true,
      parse: 'full'
  end
end
