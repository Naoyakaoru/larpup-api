require "net/http"
require "uri"
require "json"
require "opencc"

class QiandaoSearchService
  SEARCH_URL = "https://api.qiandao.com/plast/search/chaos/v5"
  CDN_BASE   = "https://treasure.qiandaocdn.com/treasure/images"
  CDN_SUFFIX = "!lfit_w600"

  HEADERS = {
    "Content-Type" => "application/json",
    "Referer"      => "https://qiandao.com/",
    "User-Agent"   => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  }.freeze

  DIFFICULTY_MAP = {
    "入门" => "easy",  "新手" => "easy",   "轻度" => "easy",
    "进阶" => "medium", "普通" => "medium",
    "困难" => "hard",  "烧脑" => "hard",   "重度" => "hard"
  }.freeze

  # Matches Script::GENRES enum values exactly
  GENRE_MAP = {
    # 0: 推理
    "推理" => 0, "本格" => 0, "新本格" => 0, "逻辑" => 0,
    # 1: 還原
    "还原" => 1, "反转" => 1,
    # 2: 恐怖
    "恐怖" => 2, "惊悚" => 2, "微恐" => 2,
    # 3: 情感
    "情感" => 3, "纯爱" => 3, "治愈" => 3, "亲情" => 3,
    # 4: 歡樂
    "欢乐" => 4,
    # 5: 機制
    "机制" => 5, "设定系" => 5,
    # 6: 陣營
    "阵营" => 6,
    # 7: 古風
    "古风" => 7, "古代" => 7, "武侠" => 7, "仙侠" => 7,
    # 8: 現代
    "现代" => 8, "近现代" => 8, "都市" => 8, "校园" => 8, "豪门" => 8,
    # 9: 日式
    "日式" => 9,
    # 10: 中式
    "中式" => 10,
    # 11: 民國
    "民国" => 11,
    # 12: 社會
    "社会" => 12,
    # 13: 刑偵
    "刑侦" => 13,
    # 14: 演繹
    "演绎" => 14, "演绎交互" => 14, "沉浸" => 14,
    # 15: 城限
    "城限" => 15,
    # 16: 獨家
    "独家" => 16
  }.freeze

  def self.call(title)
    new(title).call
  end

  def initialize(title)
    @title = title
  end

  def call
    spu = find_spu
    return nil unless spu

    tag_names = (spu["tag_names"] || []).map { |t| t.gsub(/\/.*/, "").strip }
    cover_id  = extract_cover_id(spu["image"] || spu["cover"] || "")
    kp        = spu["key_property"] || ""
    publisher = kp.split("/").map(&:strip)[1]

    {
      title:          @title,
      difficulty:     parse_difficulty(tag_names),
      genres:         parse_genres(tag_names),
      male_slots:     parse_slots(tag_names)[:male],
      female_slots:   parse_slots(tag_names)[:female],
      any_slots:      parse_slots(tag_names)[:any],
      duration:       nil,
      description:    "",
      publisher:      publisher,
      cover_image_id: cover_id,
      key_property:   kp
    }
  end

  private

  def find_spu
    query = to_simplified(@title.to_s).force_encoding("UTF-8")
    body = JSON.generate(
      q: query, startIndex: 0, maxResults: 10,
      origin: "search", version: "5", scene: "qiandao_web"
    )
    uri  = URI(SEARCH_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.read_timeout = 15
    http.open_timeout = 5

    req = Net::HTTP::Post.new(uri.path, HEADERS)
    req.body = body

    resp  = http.request(req)
    items = JSON.parse(resp.body).dig("data", "items") || []

    # Prefer exact name match, otherwise take first spu
    best = nil
    items.each do |item|
      next unless item["type"] == "spu"
      show = item["spuShow"] || {}
      next unless show["type_id"].present?
      return show if to_simplified(show["name"].to_s) == to_simplified(@title.to_s)
      best ||= show
    end
    best
  rescue
    nil
  end

  def to_simplified(text)
    OpenCC.with(:t2s) { |cc| cc.convert(text) }
  end

  def extract_cover_id(url)
    return "" if url.blank?
    url[/\.image\/([^?]+)/, 1] || ""
  end

  def parse_difficulty(tags)
    tags.each do |t|
      d = DIFFICULTY_MAP[t]
      return d if d
    end
    "medium"
  end

  def parse_genres(tags)
    seen = Set.new
    tags.filter_map do |t|
      gid = GENRE_MAP[t]
      next if gid.nil? || seen.include?(gid)
      seen.add(gid)
      gid
    end
  end

  def parse_slots(tags)
    tags.each do |t|
      if (m = t.match(/(\d+)男(\d+)女/))
        return { male: m[1].to_i, female: m[2].to_i, any: 0 }
      elsif (m = t.match(/^(\d+)人$/))
        return { male: 0, female: 0, any: m[1].to_i }
      end
    end
    { male: 0, female: 0, any: 0 }
  end
end
