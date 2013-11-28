should = require "should"
filter = require '../filter.js'

describe '#messageFilterPyazoAutoInlineDisplay', ->
  describe 'yairc.cfe.jp', ->
    describe '対応しているファイル', ->
      expected = (extension) ->
        return "<a href='//yairc.cfe.jp/testIMAGE123.#{extension}' target='_blank'><img src='//yairc.cfe.jp/testIMAGE123.#{extension}' style='max-width:300px;max-height:300px;'/></a>"
      filtered_rightly = (baseUri, extension) ->
        filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

      describe 'http', ->
        baseUri = (port) -> return "http://yairc.cfe.jp#{port}/testIMAGE123."

        it 'jpegを受け入れて変換する', -> filtered_rightly(baseUri(''), 'jpeg')
        it 'jpgを受け入れて変換する',  -> filtered_rightly(baseUri(''), 'jpg')
        it 'pngを受け入れて変換する',  -> filtered_rightly(baseUri(''), 'png')
        it 'gifを受け入れて変換する',  -> filtered_rightly(baseUri(''), 'gif')

        describe '5000番ポート', ->
          it 'jpegを受け入れて変換する', -> filtered_rightly(baseUri(':5000'), 'jpeg')

      describe 'https', ->
        baseUri = 'https://yairc.cfe.jp/testIMAGE123.'
        it 'jpegを受け入れて変換する', -> filtered_rightly(baseUri, 'jpeg')

    describe '非対応ファイル', ->
      uri      = (scheme, port) -> return "#{scheme}://yairc.cfe.jp#{port}/testIMAGE123.docx"
      expected = "<a href='//yairc.cfe.jp/testIMAGE123.docx' target='_blank'>//yairc.cfe.jp/testIMAGE123.docx</a>"
      filtered_rightly = (uri) ->
        filter.messageFilterPyazoAutoInlineDisplay(uri).should.equal(expected)

      describe 'http', ->
        it '非対応ファイルタイプはそのままリンクとして扱う', -> filtered_rightly(uri('http', ''))

        describe '5000番ポート', ->
          it '非対応ファイルタイプはそのままリンクとして扱う', -> filtered_rightly(uri('http', ':5000'))

      describe 'https', ->
        it '非対応ファイルタイプはそのままリンクとして扱う', -> filtered_rightly(uri('https', ''))

  describe 'pyazo.hachiojipm.org', ->
    describe '対応しているファイル', ->
      baseUri  = (port) -> return "http://pyazo.hachiojipm.org#{port}/testIMAGE123."
      expected = (extension) ->
        return "<a href='//pyazo.hachiojipm.org/testIMAGE123.#{extension}' target='_blank'><img src='//pyazo.hachiojipm.org/testIMAGE123.#{extension}' style='max-width:300px;max-height:300px;'/></a>"
      filtered_rightly = (baseUri, extension) ->
        filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

      it 'jpegを受け入れて変換する', -> filtered_rightly(baseUri(''), 'jpeg');
      it 'jpgを受け入れて変換する',  -> filtered_rightly(baseUri(''), 'jpg');
      it 'pngを受け入れて変換する',  -> filtered_rightly(baseUri(''), 'png');
      it 'gifを受け入れて変換する',  -> filtered_rightly(baseUri(''), 'gif');

      describe '5000番ポート', ->
        it 'jpegを受け入れて変換する', -> filtered_rightly(baseUri(':5000'), 'jpeg');

    describe '非対応ファイル', ->
      uri      = (port) -> return "http://pyazo.hachiojipm.org#{port}/testIMAGE123.docx"
      expected = "<a href='//pyazo.hachiojipm.org/testIMAGE123.docx' target='_blank'>//pyazo.hachiojipm.org/testIMAGE123.docx</a>"
      filtered_rightly = (uri) ->
        filter.messageFilterPyazoAutoInlineDisplay(uri).should.equal(expected)

      it '非対応ファイルタイプはそのままリンクとして扱う', -> filtered_rightly(uri(''))

      describe '5000番ポート', ->
        it '非対応ファイルタイプはそのままリンクとして扱う', -> filtered_rightly(uri(':5000'))
