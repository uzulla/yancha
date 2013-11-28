var should = require("should");
var filter = require('../filter.js');

describe('#messageFilterPyazoAutoInlineDisplay', function () {
    describe('yaircバーチャルドメイン', function () {
        var expected = function (extension) {
            return "<a href='//yairc.cfe.jp/testIMAGE123." + extension + "' target='_blank'><img src='//yairc.cfe.jp/testIMAGE123." + extension + "' style='max-width:300px;max-height:300px;'/></a>"
        };
        describe('http', function () {
            var baseUri = 'http://yairc.cfe.jp/testIMAGE123.';
            it('jpegを受け入れて変換する', function () {
                var extension = 'jpeg';
                filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension));
            });
            it('jpgを受け入れて変換する', function () {
                var extension = 'jpg';
                filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension));
            });
            it('pngを受け入れて変換する', function () {
                var extension = 'png';
                filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension));
            });
            it('gifを受け入れて変換する', function () {
                var extension = 'gif';
                filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension));
            });
            describe('5000番ポート', function () {
                var baseUri = 'http://yairc.cfe.jp:5000/testIMAGE123.';
                it('jpegを受け入れて変換する', function () {
                    var extension = 'jpeg';
                    filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension));
                });
            });
        });
        describe('https', function () {
            var baseUri = 'https://yairc.cfe.jp/testIMAGE123.';
            it('jpegを受け入れて変換する', function () {
                var extension = 'jpeg';
                filter.messageFilterPyazoAutoInlineDisplay(baseUri + extension).should.equal(expected(extension));
            });
        });
    });
});
