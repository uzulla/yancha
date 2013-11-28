should = require "should"
filter = require '../filter.js'

describe '#messageFilterPyazoAutoInlineDisplay', ->
  describe 'yaircバーチャルドメイン', ->
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
