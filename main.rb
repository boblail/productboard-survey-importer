require "csv"
require "digest"
require "http"
require "json"
require "sinatra"


API_TOKEN = ENV.fetch("PRODUCTBOARD_API_TOKEN") do
  puts <<~TEXT
    You are missing a PRODUCTBOARD_API_TOKEN. To get one, follow these instructions:

       https://developer.productboard.com/#section/Authentication

    Then export it as an environment variables named PRODUCTBOARD_API_TOKEN
  TEXT
  exit 1
end
UPLOADS = {} # like an in-memory database

COMMON_SURVEY_FIELDS_TO_IGNORE = [
  "Timestamp"
].freeze

COMMON_SURVEY_RESPONSES_TO_IGNORE = [
  "",
  "Yes",
  "No",
  "Strongly disagree",
  "Disagree",
  "Neutral",
  "Agree",
  "Strongly agree",
].freeze


get "/" do
  send_file "index.html"
end

post "/uploads" do
  filename = params.dig(:file, :filename)
  file = params.dig(:file, :tempfile).read
  file.force_encoding "UTF-8"

  csv =
    begin
      CSV.parse(file).to_a
    rescue CSV::MalformedCSVError => e
      return JSON.dump(ok: false, error: "Invalid CSV file: " + e.message)
    end

  id = Digest::MD5.hexdigest(file)
  UPLOADS[id] = file

  headings = []
  Array(csv.shift).each_with_index do |heading, i|
    next if COMMON_SURVEY_FIELDS_TO_IGNORE.member?(heading)
    next if csv.all? { |row| COMMON_SURVEY_RESPONSES_TO_IGNORE.member?(row[i].to_s.strip) }
    example = csv.lazy.map { |row| row[i] }.find { |value| value && !value.empty? }
    headings.push(text: heading, index: i, example: example)
  end

  JSON.dump(
    ok: true,
    uploadId: id,
    filename: filename,
    headings: headings
  )
end

post "/uploads/:id/import" do
  customer_fields = params.fetch(:customer_fields, []).map(&:to_i)
  feedback_fields = params.fetch(:feedback_fields, []).map(&:to_i)
  tags = params.fetch(:tags, "").split(/[^\w\-\/]+/)
  file = UPLOADS.fetch(params.fetch(:id))
  csv = CSV.parse(file).to_a
  headings, *rows = csv

  rows.each do |row|
    attributed_to = row
      .values_at(*customer_fields)
      .map { |val| val.to_s.strip }
      .reject(&:empty?)
      .join(", ")

    title = nil
    responses = []
    feedback_fields.each do |i|
      response, question = row[i].to_s.strip, headings[i]
      next if response.empty? || question.nil?
      title ||= response.lines.first

      responses.push <<~HTML
        <p><b>#{question}</b></p>
        <p>#{response.gsub("\n", "<br>")}</p>
      HTML
    end

    if responses.any?
       body = JSON.dump(
        title: title,
        content: responses.join("\n<br>\n"),
        customer_email: attributed_to,
        tags: tags
      )

      response = HTTP
        .auth("Bearer #{API_TOKEN}")
        .headers(
          "Productboard-Partner-Id" => "boblail/productboard-survey-importer",
          "Content-Type" => "application/json",
          "Accept" => "application/json",
        )
        .post("https://api.productboard.com/notes", body: body)

      if (200...300) === response.code
        puts "\e[32mHTTP #{response.code}\e[0m"
      else
        puts "\e[31mHTTP #{response.code}\e[0m - #{response.body}"
      end
    end
  end

  redirect "/"
end
