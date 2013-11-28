should = require "should"
filter = require '../filter.js'

describe '#messageFilterPyazoAutoInlineDisplay', ->
  describe 'yairc.cfe.jp', ->
    describe '対応しているファイル', ->
      expected = (extension) ->
        return "<a href='//yairc.cfe.jp/testIMAGE123." + extension + "' target='_blank'><img src='//yairc.cfe.jp/testIMAGE123." + extension + "' style='max-width:300px;max-height:300px;'/></a>"

      describe 'http', ->
        baseUri = 'http://yairc.cfe.jp/testIMAGE123.'
        it 'jpegを受け入れて変換する', ->
          extension = 'jpeg'
          filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

        it 'jpgを受け入れて変換する', ->
          extension = 'jpg'
          filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

        it 'pngを受け入れて変換する', ->
          extension = 'png'
          filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

        it 'gifを受け入れて変換する', ->
          extension = 'gif'
          filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

        describe '5000番ポート', ->
          baseUri = 'http://yairc.cfe.jp:5000/testIMAGE123.'
          it 'jpegを受け入れて変換する', ->
            extension = 'jpeg'
            filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

      describe 'https', ->
        baseUri = 'https://yairc.cfe.jp/testIMAGE123.'
        it 'jpegを受け入れて変換する', ->
          extension = 'jpeg'
          filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension))

    describe '非対応ファイル', ->
      host     = '://yairc.cfe.jp/testIMAGE123.docx'
      expected = "<a href='//yairc.cfe.jp/testIMAGE123.docx' target='_blank'>//yairc.cfe.jp/testIMAGE123.docx</a>"

      describe 'http', ->
        uri = 'http' + host
        it '非対応ファイルタイプはそのままリンクとして扱う', ->
          filter.messageFilterPyazoAutoInlineDisplay(uri).should.equal(expected)

        describe '5000番ポート', ->
          uri = 'http://yairc.cfe.jp:5000/testIMAGE123.docx'
          it '非対応ファイルタイプはそのままリンクとして扱う', ->
            filter.messageFilterPyazoAutoInlineDisplay(uri).should.equal(expected)

      describe 'https', ->
        uri = 'https' + host
        it '非対応ファイルタイプはそのままリンクとして扱う', ->
          filter.messageFilterPyazoAutoInlineDisplay(uri).should.equal(expected)
