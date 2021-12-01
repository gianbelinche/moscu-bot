require 'spec_helper'
require 'web_mock'
# Uncomment to use VCR
# require 'vcr_helper'

require "#{File.dirname(__FILE__)}/../app/bot_client"

CHAT_ID = 141_733_544

def when_i_send_text(token, message_text)
  body = { "ok": true, "result": [{ "update_id": 693_981_718,
                                    "message": { "message_id": 11,
                                                 "from": { "id": CHAT_ID, "is_bot": false, "first_name": 'Emilio', "last_name": 'Gutter', "username": 'egutter', "language_code": 'en' },
                                                 "chat": { "id": CHAT_ID, "first_name": 'Emilio', "last_name": 'Gutter', "username": 'egutter', "type": 'private' },
                                                 "date": 1_557_782_998, "text": message_text,
                                                 "entities": [{ "offset": 0, "length": 6, "type": 'bot_command' }] } }] }

  stub_request(:any, "https://api.telegram.org/bot#{token}/getUpdates")
    .to_return(body: body.to_json, status: 200, headers: { 'Content-Length' => 3 })
end

def when_i_send_keyboard_updates(token, message_text, inline_selection)
  body = {
    "ok": true, "result": [{
      "update_id": 866_033_907,
      "callback_query": { "id": '608740940475689651', "from": { "id": CHAT_ID, "is_bot": false, "first_name": 'Emilio', "last_name": 'Gutter', "username": 'egutter', "language_code": 'en' },
                          "message": {
                            "message_id": 626,
                            "from": { "id": 715_612_264, "is_bot": true, "first_name": 'fiuba-memo2-prueba', "username": 'fiuba_memo2_bot' },
                            "chat": { "id": CHAT_ID, "first_name": 'Emilio', "last_name": 'Gutter', "username": 'egutter', "type": 'private' },
                            "date": 1_595_282_006,
                            "text": message_text,
                            "reply_markup": {
                              "inline_keyboard": [
                                [{ "text": 'Jon Snow', "callback_data": '1' }],
                                [{ "text": 'Daenerys Targaryen', "callback_data": '2' }],
                                [{ "text": 'Ned Stark', "callback_data": '3' }]
                              ]
                            }
                          },
                          "chat_instance": '2671782303129352872',
                          "data": inline_selection }
    }]
  }

  stub_request(:any, "https://api.telegram.org/bot#{token}/getUpdates")
    .to_return(body: body.to_json, status: 200, headers: { 'Content-Length' => 3 })
end

def then_i_get_text(token, message_text)
  body = { "ok": true,
           "result": { "message_id": 12,
                       "from": { "id": 715_612_264, "is_bot": true, "first_name": 'fiuba-memo2-prueba', "username": 'fiuba_memo2_bot' },
                       "chat": { "id": CHAT_ID, "first_name": 'Emilio', "last_name": 'Gutter', "username": 'egutter', "type": 'private' },
                       "date": 1_557_782_999, "text": message_text } }

  stub_request(:post, "https://api.telegram.org/bot#{token}/sendMessage")
    .with(
      body: { 'chat_id' => '141733544', 'text' => message_text }
    )
    .to_return(status: 200, body: body.to_json, headers: {})
end

def then_i_get_keyboard_message(token, message_text)
  body = { "ok": true,
           "result": { "message_id": 12,
                       "from": { "id": 715_612_264, "is_bot": true, "first_name": 'fiuba-memo2-prueba', "username": 'fiuba_memo2_bot' },
                       "chat": { "id": CHAT_ID, "first_name": 'Emilio', "last_name": 'Gutter', "username": 'egutter', "type": 'private' },
                       "date": 1_557_782_999, "text": message_text } }

  stub_request(:post, "https://api.telegram.org/bot#{token}/sendMessage")
    .with(
      body: { 'chat_id' => '141733544',
              'reply_markup' => '{"inline_keyboard":[[{"text":"Jon Snow","callback_data":"1"}],[{"text":"Daenerys Targaryen","callback_data":"2"}],[{"text":"Ned Stark","callback_data":"3"}]]}',
              'text' => message_text }
    )
    .to_return(status: 200, body: body.to_json, headers: {})
end

describe 'BotClient' do
  it 'should get a /version message and respond with current version' do
    token = 'fake_token'

    when_i_send_text(token, '/version')
    then_i_get_text(token, Version.current)

    app = BotClient.new(token)

    app.run_once
  end

  it 'should get a /start message and respond with Moscu te saluda' do
    token = 'fake_token'

    when_i_send_text(token, '/start')
    then_i_get_text(token, 'Moscu te saluda, Emilio')

    app = BotClient.new(token)

    app.run_once
  end

  it 'should get an unknown message message and respond with Do not understand' do
    token = 'fake_token'

    when_i_send_text(token, '/unknown')
    then_i_get_text(token, 'Uh? No te entiendo! Me repetis la pregunta?')

    app = BotClient.new(token)

    app.run_once
  end
  context 'when /registrar' do
    it 'deberia responder a "/registrar juan, juan@test.com" exitosamente' do
      token = 'fake_token'

      body = {
        nombre: 'juan',
        email: 'juan@mail.com',
        id: 123
      }

      MockeadorEndpoints.new.mockear_endpoint('/usuarios', 201, body)

      when_i_send_text(token, '/registrar juan, juan@test.com')
      then_i_get_text(token, 'Bienvenido juan')

      app = BotClient.new(token)

      app.run_once
    end

    it 'deberia responder a "/registrar juan, juan@test.com" con error' do
      token = 'fake_token'

      mensaje_error = 'Error: Ya estas registrado'

      body = {
        error: mensaje_error
      }

      MockeadorEndpoints.new.mockear_endpoint('/usuarios', 400, body)

      when_i_send_text(token, '/registrar juan, juan@test.com')
      then_i_get_text(token, mensaje_error)

      app = BotClient.new(token)

      app.run_once
    end

    it 'deberia responder a "/registrar juan" con mensaje de ayuda' do
      token = 'fake_token'

      mensaje_error = 'Error: El uso del comando es /registrar <nombre>,<email>'

      when_i_send_text(token, '/registrar juan')
      then_i_get_text(token, mensaje_error)

      app = BotClient.new(token)

      app.run_once
    end
  end

  context 'when /ingresar_auto' do
    it 'deberia responder a "/ingresar_auto Fiat Uno,ABC123,10000,1990" exitosamente' do
      token = 'fake_token'

      body = {
        patente: 'ABC123',
        modelo: 'Fiat Uno',
        kilometros: 10_000,
        anio: 1990,
        id_prop: 1234,
        estado: 'En revision'
      }

      MockeadorEndpoints.new.mockear_endpoint('/autos', 201, body)

      when_i_send_text(token, '/ingresar_auto Fiat Uno,ABC123,10000,1990')
      then_i_get_text(token, 'Auto con patente ABC123 ingresado al sistema')

      app = BotClient.new(token)

      app.run_once
    end

    it 'deberia responder a "/ingresar_auto Fiat Uno,ABC123,10000,1990" con error' do
      token = 'fake_token'

      mensaje_error = 'Error: Auto ya registrado'

      body = {
        error: mensaje_error
      }

      MockeadorEndpoints.new.mockear_endpoint('/autos', 400, body)

      when_i_send_text(token, '/ingresar_auto Fiat Uno,ABC123,10000,1990')
      then_i_get_text(token, mensaje_error)

      app = BotClient.new(token)

      app.run_once
    end

    it 'deberia responder a "/ingresar_auto Fiat Uno" con mensaje de ayuda' do
      token = 'fake_token'

      mensaje_error = 'Error: El uso del comando es /ingresar_auto <modelo>,<patente>,<kilometros>,<año>'

      when_i_send_text(token, '/ingresar_auto Fiat Uno')
      then_i_get_text(token, mensaje_error)

      app = BotClient.new(token)

      app.run_once
    end
  end

  context 'when /consultar_mis_autos' do
    let(:auto) do
      {
        patente: 'ABC123',
        modelo: 'Fiat Uno',
        kilometros: 10_000,
        anio: 1990,
        id_prop: 1234,
        estado: 'En revision'
      }
    end

    it 'deberia responder exitosamente' do
      token = 'fake_token'

      body = [auto]

      MockeadorEndpoints.new.mockear_get("/usuarios/#{CHAT_ID}/autos", 200, body)

      when_i_send_text(token, '/consultar_mis_autos')
      then_i_get_text(token, '#1 ABC123, En revision')

      app = BotClient.new(token)

      app.run_once
    end

    it 'deberia responder con un auto cotizado' do
      token = 'fake_token'

      auto1 = {
        patente: 'ABC123',
        modelo: 'Fiat Uno',
        kilometros: 10_000,
        anio: 1990,
        id_prop: 1234,
        estado: 'Cotizado',
        precio: 5000
      }

      body = [auto1]

      MockeadorEndpoints.new.mockear_get("/usuarios/#{CHAT_ID}/autos", 200, body)

      when_i_send_text(token, '/consultar_mis_autos')
      then_i_get_text(token, '#1 ABC123, Cotizado, 5000')

      app = BotClient.new(token)

      app.run_once
    end

    it 'deberia responder con varios autos' do
      token = 'fake_token'

      auto1 = {
        patente: 'AB123CD',
        modelo: 'Fiat Uno',
        kilometros: 10_000,
        anio: 1990,
        id_prop: 1234,
        estado: 'Cotizado',
        precio: 5000
      }

      body = [auto1, auto]

      MockeadorEndpoints.new.mockear_get("/usuarios/#{CHAT_ID}/autos", 200, body)

      when_i_send_text(token, '/consultar_mis_autos')
      then_i_get_text(token, "#1 AB123CD, Cotizado, 5000\n#2 ABC123, En revision")

      app = BotClient.new(token)

      app.run_once
    end
  end
end
