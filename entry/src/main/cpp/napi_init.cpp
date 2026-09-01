#include <napi/native_api.h>
#include <string>
#include <vector>
#include "md4c.h"

// ---------------------------------------------------------------------------
// C 端：markdown SAX 事件收集器（MD4C 解析）
// 输出结构（NAPI 数组）：
//   [ {t:"block", name:"h1"}, {t:"leave", name:"h1"},
//     {t:"text", text:"Hello"},
//     {t:"span", name:"strong"}, ... ]
// ArkTS 侧据事件流构建 ArkUI 组件树（无 WebView）。
// ---------------------------------------------------------------------------

namespace {

struct EventItem {
  std::string type;    // block / leaveBlock / span / leaveSpan / text
  std::string name;    // h1..h6 / p / ul / ol / li / code / pre / quote / img / a / em / strong / ...（空=文本）
  std::string text;    // text 事件的文本
  std::string extra;   // img: src; a: href; li: marker
};

struct EventCollector {
  std::vector<EventItem> events;
  int nesting = 0;     // 可选：调试用
};

void addEvent(EventCollector& c, const std::string& type, const std::string& name,
              const std::string& text = "", const std::string& extra = "") {
  EventItem item;
  item.type = type;
  item.name = name;
  item.text = text;
  item.extra = extra;
  c.events.push_back(item);
}

static int cbEnterBlock(MD_BLOCKTYPE type, void* detail, void* userdata) {
  EventCollector& c = *static_cast<EventCollector*>(userdata);
  const char* name = "unknown";
  switch (type) {
    case MD_BLOCK_DOC: name = "doc"; break;
    case MD_BLOCK_QUOTE: name = "quote"; break;
    case MD_BLOCK_UL: name = "ul"; break;
    case MD_BLOCK_OL: name = "ol"; break;
    case MD_BLOCK_LI: name = "li"; break;
    case MD_BLOCK_HR: name = "hr"; break;
    case MD_BLOCK_H: {
      const MD_BLOCK_H_DETAIL* d = (const MD_BLOCK_H_DETAIL*) detail;
      switch (d->level) { case 1: name = "h1"; break; case 2: name = "h2"; break;
        case 3: name = "h3"; break; case 4: name = "h4"; break;
        case 5: name = "h5"; break; default: name = "h6"; break; }
      break;
    }
    case MD_BLOCK_P: name = "p"; break;
    case MD_BLOCK_CODE: {
      const MD_BLOCK_CODE_DETAIL* d = (const MD_BLOCK_CODE_DETAIL*) detail;
      name = "code";
      break;
    }
    case MD_BLOCK_HTML: name = "html"; break;
    case MD_BLOCK_TABLE: name = "table"; break;
    case MD_BLOCK_THEAD: name = "thead"; break;
    case MD_BLOCK_TBODY: name = "tbody"; break;
    case MD_BLOCK_TR: name = "tr"; break;
    case MD_BLOCK_TH: name = "th"; break;
    case MD_BLOCK_TD: name = "td"; break;
    default: break;
  }
  addEvent(c, "block", name);
  return 0;
}

static int cbLeaveBlock(MD_BLOCKTYPE type, void* detail, void* userdata) {
  EventCollector& c = *static_cast<EventCollector*>(userdata);
  const char* name = "unknown";
  switch (type) {
    case MD_BLOCK_DOC: name = "doc"; break;
    case MD_BLOCK_QUOTE: name = "quote"; break;
    case MD_BLOCK_UL: name = "ul"; break;
    case MD_BLOCK_OL: name = "ol"; break;
    case MD_BLOCK_LI: name = "li"; break;
    case MD_BLOCK_HR: name = "hr"; break;
    case MD_BLOCK_H: {
      const MD_BLOCK_H_DETAIL* d = (const MD_BLOCK_H_DETAIL*) detail;
      switch (d->level) { case 1: name = "h1"; break; case 2: name = "h2"; break;
        case 3: name = "h3"; break; case 4: name = "h4"; break;
        case 5: name = "h5"; break; default: name = "h6"; break; }
      break;
    }
    case MD_BLOCK_P: name = "p"; break;
    case MD_BLOCK_CODE: name = "code"; break;
    case MD_BLOCK_HTML: name = "html"; break;
    case MD_BLOCK_TABLE: name = "table"; break;
    case MD_BLOCK_THEAD: name = "thead"; break;
    case MD_BLOCK_TBODY: name = "tbody"; break;
    case MD_BLOCK_TR: name = "tr"; break;
    case MD_BLOCK_TH: name = "th"; break;
    case MD_BLOCK_TD: name = "td"; break;
    default: break;
  }
  addEvent(c, "leaveBlock", name);
  return 0;
}

static int cbEnterSpan(MD_SPANTYPE type, void* detail, void* userdata) {
  EventCollector& c = *static_cast<EventCollector*>(userdata);
  const char* name = "span";
  std::string extra;
  switch (type) {
    case MD_SPAN_EM: name = "em"; break;
    case MD_SPAN_STRONG: name = "strong"; break;
    case MD_SPAN_A: {
      const MD_SPAN_A_DETAIL* d = (const MD_SPAN_A_DETAIL*) detail;
      name = "a";
      if (d->href.text) extra = std::string(d->href.text, d->href.size);
      break;
    }
    case MD_SPAN_IMG: {
      const MD_SPAN_IMG_DETAIL* d = (const MD_SPAN_IMG_DETAIL*) detail;
      name = "img";
      if (d->src.text) extra = std::string(d->src.text, d->src.size);
      break;
    }
    case MD_SPAN_CODE: name = "code"; break;
    case MD_SPAN_DEL: name = "del"; break;
    case MD_SPAN_LATEXMATH: name = "latex"; break;
    case MD_SPAN_LATEXMATH_DISPLAY: name = "latex"; break;
    case MD_SPAN_WIKILINK: name = "wikilink"; break;
    case MD_SPAN_U: name = "u"; break;
    default: break;
  }
  addEvent(c, "span", name, "", extra);
  return 0;
}

static int cbLeaveSpan(MD_SPANTYPE type, void* detail, void* userdata) {
  EventCollector& c = *static_cast<EventCollector*>(userdata);
  const char* name = "span";
  switch (type) {
    case MD_SPAN_EM: name = "em"; break;
    case MD_SPAN_STRONG: name = "strong"; break;
    case MD_SPAN_A: name = "a"; break;
    case MD_SPAN_IMG: name = "img"; break;
    case MD_SPAN_CODE: name = "code"; break;
    case MD_SPAN_DEL: name = "del"; break;
    case MD_SPAN_LATEXMATH: name = "latex"; break;
    case MD_SPAN_LATEXMATH_DISPLAY: name = "latex"; break;
    default: break;
  }
  addEvent(c, "leaveSpan", name);
  return 0;
}

static int cbText(MD_TEXTTYPE type, const MD_CHAR* text, MD_SIZE size, void* userdata) {
  EventCollector& c = *static_cast<EventCollector*>(userdata);
  std::string t(text, size);
  switch (type) {
    case MD_TEXT_NORMAL:
      addEvent(c, "text", "", t);
      break;
    case MD_TEXT_BR:
      addEvent(c, "text", "br", "");
      break;
    case MD_TEXT_SOFTBR:
      // 软换行：保留空格语义即可（ArkUI 会自己排版），这里映射为空格
      addEvent(c, "text", "", " ");
      break;
    case MD_TEXT_CODE:
      addEvent(c, "text", "codeText", t);
      break;
    default:
      addEvent(c, "text", "", t);
      break;
  }
  return 0;
}

// 把 markdown 字符串解析成事件数组（NAPI 数组）
napi_value ParseMarkdown(napi_env env, napi_callback_info info) {
  size_t argc = 1;
  napi_value argv[1] = {nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

  // 读入 markdown 字符串
  size_t len = 0;
  napi_get_value_string_utf8(env, argv[0], nullptr, 0, &len);
  std::string md;
  md.resize(len);
  napi_get_value_string_utf8(env, argv[0], &md[0], len + 1, &len);

  EventCollector collector;
  MD_PARSER parser;
  memset(&parser, 0, sizeof(parser));
  parser.flags = 0;                      // CommonMark 规范
  parser.enter_block = cbEnterBlock;
  parser.leave_block = cbLeaveBlock;
  parser.enter_span = cbEnterSpan;
  parser.leave_span = cbLeaveSpan;
  parser.text = cbText;

  md_parse(md.data(), md.size(), &parser, &collector);

  napi_value result;
  napi_create_array_with_length(env, collector.events.size(), &result);

  for (size_t i = 0; i < collector.events.size(); i++) {
    const EventItem& e = collector.events[i];
    napi_value obj;
    napi_create_object(env, &obj);

    napi_value vType;
    napi_create_string_utf8(env, e.type.c_str(), e.type.size(), &vType);
    napi_set_named_property(env, obj, "t", vType);

    napi_value vName;
    napi_create_string_utf8(env, e.name.c_str(), e.name.size(), &vName);
    napi_set_named_property(env, obj, "name", vName);

    if (!e.text.empty()) {
      napi_value vText;
      napi_create_string_utf8(env, e.text.c_str(), e.text.size(), &vText);
      napi_set_named_property(env, obj, "text", vText);
    }
    if (!e.extra.empty()) {
      napi_value vExtra;
      napi_create_string_utf8(env, e.extra.c_str(), e.extra.size(), &vExtra);
      napi_set_named_property(env, obj, "extra", vExtra);
    }

    napi_set_element(env, result, i, obj);
  }
  return result;
}

napi_value Export(napi_env env, napi_value exports) {
  napi_value fn;
  napi_create_function(env, "parseMarkdown", NAPI_AUTO_LENGTH, ParseMarkdown, nullptr, &fn);
  napi_set_named_property(env, exports, "parseMarkdown", fn);
  return exports;
}

}  // namespace

static napi_module md4cModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Export,
    .nm_modname = "md4c",
    .nm_priv = nullptr,
    .reserved = {nullptr},
};

extern "C" __attribute__((constructor)) void RegisterMd4cModule() {
  napi_module_register(&md4cModule);
}
