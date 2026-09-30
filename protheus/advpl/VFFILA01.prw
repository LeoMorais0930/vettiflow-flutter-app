#Include "TOTVS.ch"

/*/{Protheus.doc} VFFILA01
Consumidor da fila de solicitacoes do VettiFlow - opcao de menu.

Operacoes: abertura de OP (MATA650) e exclusao seletiva (U_VFEMP01/MATA381).
Fluxo: lista os pedidos pendentes na API do VettiFlow, mostra um por vez,
e so depois da confirmacao do usuario reserva o pedido, executa a MATA650
e devolve o resultado. A API confere a OP por SELECT antes de marcar
"aplicada".

A API nunca grava no ERP: quem grava e a rotina oficial, aqui.

Configuracao no appserver.ini do ambiente (nao em SX6, para a chave nao
ficar visivel no configurador):
    [VETTIFLOW]
    Url=http://servidor-da-api:8000/api/v1
    ConsumerKey=<VF_QUEUE_CONSUMER_TOKEN da API>
    ApiToken=<VF_API_TOKEN da API, se configurado>
    SessionToken=<JWT temporario do mesmo usuario do menu, somente DEV>

NAO COMPILADO/HOMOLOGADO. Pendencias em protheus/advpl/README.md.
@type  User Function
/*/
Static cVFUrl := ""
Static cVFKey := ""
Static cVFTok := ""
Static cVFJwt := ""

User Function VFFILA01(cSessionToken)
    Local aPend    := {}
    Local nI       := 0
    Local oPed     := Nil
    Local cResumo  := ""

    If !VFConfig(cSessionToken)
        Return
    EndIf

    // A fila so atende grupo 01 / filial 04 (tabelas 010, base HMLp12).
    If AllTrim(cEmpAnt) != "01" .Or. AllTrim(cFilAnt) != "04"
        MsgStop("Entre no grupo 01, filial 04 para processar a fila do VettiFlow.", "VettiFlow")
        Return
    EndIf

    If !VFAuth()
        Return
    EndIf
    aPend := VFPendentes()
    If aPend == Nil
        Return
    EndIf
    If Len(aPend) == 0
        MsgInfo("Nenhum pedido pendente na fila do VettiFlow.", "VettiFlow")
        Return
    EndIf

    For nI := 1 To Len(aPend)
        oPed    := aPend[nI]
        cResumo := VFResumo(oPed)
        If MsgYesNo(cResumo + CRLF + CRLF + "Executar este pedido agora?", ;
                    "VettiFlow - pedido " + cValToChar(nI) + " de " + cValToChar(Len(aPend)))
            VFProcessa(oPed["id"])
            Exit
        EndIf
    Next nI
Return

/*/ Le a configuracao do appserver.ini. /*/
Static Function VFConfig(cSessionToken)
    Local cIni := GetAdv97()
    Local cEnv := Upper(AllTrim(GetEnvServer()))

    If cEnv != "P12DEV" .And. cEnv != "P12REST"
        MsgStop("Consumidor liberado somente para P12DEV/P12REST nesta homologacao.", "VettiFlow")
        Return .F.
    EndIf
    cVFJwt := IIf(ValType(cSessionToken) == "C", cSessionToken, "")
    If Empty(cVFJwt)
        cVFJwt := AllTrim(GetPvProfString("VETTIFLOW", "SessionToken", "", cIni))
    EndIf
    If Empty(cVFJwt)
        MsgStop("Informe um JWT ativo do VettiFlow no parametro de U_VFFILA01 ou SessionToken no ini DEV.", "VettiFlow")
        Return .F.
    EndIf

    cVFUrl := AllTrim(GetPvProfString("VETTIFLOW", "Url", "", cIni))
    cVFKey := AllTrim(GetPvProfString("VETTIFLOW", "ConsumerKey", "", cIni))
    cVFTok := AllTrim(GetPvProfString("VETTIFLOW", "ApiToken", "", cIni))
    If Right(cVFUrl, 1) == "/"
        cVFUrl := Left(cVFUrl, Len(cVFUrl) - 1)
    EndIf
    If Empty(cVFUrl) .Or. Empty(cVFKey)
        MsgStop("Configure Url e ConsumerKey na secao [VETTIFLOW] do appserver.ini.", "VettiFlow")
        Return .F.
    EndIf
Return .T.

/*/ Chamada HTTP a API do VettiFlow. Devolve o corpo; nStatus por referencia. /*/
Static Function VFHttp(cMetodo, cPath, cBody, nStatus)
    Local aHead := {}
    Local cHead := ""
    Local cResp := ""

    aAdd(aHead, "Content-Type: application/json")
    aAdd(aHead, "Accept: application/json")
    aAdd(aHead, "Authorization: Bearer " + cVFJwt)
    aAdd(aHead, "X-VettiFlow-Consumer-Key: " + cVFKey)
    If !Empty(cVFTok)
        aAdd(aHead, "X-API-Token: " + cVFTok)
    EndIf

    If cMetodo == "GET"
        cResp := HttpGet(cVFUrl + cPath, "", 30, aHead, @cHead)
    Else
        cResp := HttpPost(cVFUrl + cPath, "", EncodeUTF8(cBody), 60, aHead, @cHead)
    EndIf

    nStatus := VFStatus(cHead)
    If ValType(cResp) != "C"
        cResp := ""
    EndIf
Return DecodeUTF8(cResp)

/*/ Codigo HTTP da primeira linha do cabecalho ("HTTP/1.1 200 OK"). /*/
Static Function VFStatus(cHead)
    Local nPos := 0

    If ValType(cHead) != "C" .Or. Empty(cHead)
        Return 0
    EndIf
    nPos := At(" ", cHead)
Return Val(SubStr(cHead, nPos + 1, 3))

/*/ Converte uma resposta JSON; array no topo e embrulhado em "itens". /*/
Static Function VFJson(cTexto, lArray)
    Local oJson := JsonObject():New()
    Local xErro := Nil

    If lArray
        cTexto := '{"itens":' + cTexto + '}'
    EndIf
    xErro := oJson:FromJson(cTexto)
    If ValType(xErro) == "C"
        Return Nil
    EndIf
Return oJson

// JWT deve pertencer ao mesmo usuario que executa no menu do Protheus.
Static Function VFAuth()
    Local nStatus := 0
    Local oSessao := Nil
    Local cResp := VFHttp("GET", "/auth/protheus/session", "", @nStatus)
    If nStatus != 200
        MsgStop("Sessao VettiFlow ausente ou expirada. Renove o login e o JWT antes de executar.", "VettiFlow")
        Return .F.
    EndIf
    oSessao := VFJson(cResp, .F.)
    If oSessao == Nil
        Return .F.
    EndIf
    If Lower(AllTrim(oSessao["username"])) != Lower(AllTrim(UsrRetName(RetCodUsr())))
        MsgStop("O JWT deve ser do usuario logado neste Protheus.", "VettiFlow")
        Return .F.
    EndIf
Return .T.

Static Function VFPendentes()
    Local nStatus := 0
    Local cResp   := VFHttp("GET", "/consumidor/pendentes", "", @nStatus)
    Local oLista  := Nil

    If nStatus != 200
        MsgStop("API do VettiFlow respondeu " + cValToChar(nStatus) + " ao listar pendentes." + ;
                CRLF + Left(cResp, 300), "VettiFlow")
        Return Nil
    EndIf
    oLista := VFJson(cResp, .T.)
    If oLista == Nil
        MsgStop("Resposta invalida da API ao listar pendentes.", "VettiFlow")
        Return Nil
    EndIf
Return oLista["itens"]

Static Function VFResumo(oPed)
    Local oPay := oPed["payload"]
    Local cItens := ""
    Local nI := 0
    Local nPos := 0
    Local oRow := Nil
    If oPed["operacao"] == "exclusao_empenhos"
        For nI := 1 To Len(oPay["excluded"])
            nPos := aScan(oPay["snapshot"]["items"], {|r| r["id"] == oPay["excluded"][nI]["id"]})
            If nPos > 0
                oRow := oPay["snapshot"]["items"][nPos]
                cItens += oRow["produto"] + " / arm. " + oRow["local"] + " / qtd. " + ;
                          cValToChar(oRow["quantidade"]) + " - " + oPay["excluded"][nI]["reason"] + CRLF
            EndIf
        Next nI
        Return "Pedido " + Left(oPed["id"], 8) + " de " + oPed["solicitante"] + CRLF + ;
               "EXCLUIR " + cValToChar(Len(oPay["excluded"])) + " empenho(s) da OP " + oPay["op"] + CRLF + ;
               cItens + "Os demais empenhos e os itens MOD serao mantidos."
    EndIf
Return "Pedido " + Left(oPed["id"], 8) + " de " + oPed["solicitante"] + CRLF + ;
       "Operacao: " + oPed["operacao"] + CRLF + ;
       "Produto: " + oPay["produto"] + CRLF + ;
       "Quantidade: " + cValToChar(oPay["quantidade"]) + CRLF + ;
       "Armazem: " + oPay["armazem"] + CRLF + ;
       "Inicio: " + oPay["dataInicio"] + "  Entrega: " + oPay["dataEntrega"]

/*/ Reserva, executa e devolve o resultado de um pedido. /*/
Static Function VFProcessa(cId)
    Local nStatus  := 0
    Local cResp    := ""
    Local oPed     := Nil
    Local aRes     := {}
    Local cCorpo   := ""
    Local nTent    := 0
    Local lEnviado := .F.

    If !VFAuth()
        Return
    EndIf
    cResp := VFHttp("POST", "/consumidor/solicitacoes/" + cId + "/reservar", "{}", @nStatus)
    If nStatus != 200
        MsgStop("Nao foi possivel reservar o pedido (" + cValToChar(nStatus) + "). " + ;
                "Nada foi executado." + CRLF + Left(cResp, 300), "VettiFlow")
        Return
    EndIf
    oPed := VFJson(cResp, .F.)
    If oPed == Nil .Or. Empty(oPed["reserva"])
        // Reservado sem resposta legivel: vira "incerta" pela API ao vencer.
        MsgStop("Resposta invalida ao reservar. Nada foi executado; o pedido vai " + ;
                "aparecer como incerto na fila.", "VettiFlow")
        Return
    EndIf
    If oPed["empresa"] != "01" .Or. oPed["filial"] != "04"
        aRes := {.F., .T., {}, "Pedido fora do escopo deste consumidor.", ""}
    ElseIf oPed["operacao"] == "abertura_op"
        aRes := VFAbreOP(oPed)
    ElseIf oPed["operacao"] == "exclusao_empenhos"
        aRes := U_VFEMP01(oPed)
    Else
        aRes := {.F., .T., {}, "Operacao nao suportada por este consumidor.", ""}
    EndIf

    cCorpo := VFCorpoResultado(oPed["reserva"], aRes)
    // Falha no retorno nunca autoriza executar de novo: so reenvia o resultado.
    For nTent := 1 To 3
        cResp := VFHttp("POST", "/consumidor/solicitacoes/" + cId + "/resultado", cCorpo, @nStatus)
        If nStatus == 200
            lEnviado := .T.
            Exit
        EndIf
        Sleep(2000)
    Next nTent

    If !lEnviado
        MsgStop("O resultado NAO chegou a API (" + cValToChar(nStatus) + ")." + CRLF + ;
                "NAO execute este pedido de novo. Referencia: " + VFRefs(aRes[3]) + CRLF + ;
                aRes[4], "VettiFlow")
        Return
    EndIf
    oPed := VFJson(cResp, .F.)
    MsgInfo("Situacao na fila: " + IIf(oPed == Nil, "?", oPed["status"]) + CRLF + ;
            "Referencia: " + VFRefs(aRes[3]) + CRLF + aRes[4], "VettiFlow")
Return

Static Function VFRefs(aRefs)
    Local cTxt := ""
    Local nI   := 0

    For nI := 1 To Len(aRefs)
        cTxt += IIf(nI > 1, ", ", "") + aRefs[nI]
    Next nI
Return IIf(Empty(cTxt), "(nenhuma)", cTxt)

Static Function VFCorpoResultado(cReserva, aRes)
    Local oRes := JsonObject():New()

    oRes["reserva"]      := cReserva
    oRes["sucesso"]      := aRes[1]
    oRes["semEfeito"]    := aRes[2]
    oRes["protheusRefs"] := aRes[3]
    oRes["mensagem"]     := Left(aRes[4], 2000)
    oRes["logExecauto"]  := Left(aRes[5], 20000)
    oRes["executor"]     := Left(AllTrim(UsrRetName(RetCodUsr())), 80)
Return oRes:ToJson()

/*/{Protheus.doc} VFAbreOP
Executor da abertura: sem nenhuma tela, para poder rodar em job depois.
Retorna {lSucesso, lSemEfeito, aRefs, cMensagem, cLogExecAuto}.
lSemEfeito so e .T. quando o rollback foi CONFERIDO na SC2.
/*/
Static Function VFAbreOP(oPed)
    Local oPay      := oPed["payload"]
    Local cNum      := ""
    Local cProduto  := PadR(oPay["produto"], TamSX3("C2_PRODUTO")[1])
    Local cObs      := Left("VF:" + Left(oPed["id"], 8) + " " + oPay["observacao"], TamSX3("C2_OBS")[1])
    Local aCab      := {}
    Local aRefs     := {}
    Local cLog      := ""
    Local cFalha    := ""
    Local bErroAnt  := Nil
    Local lSucesso  := .F.
    Local lSemEfeito := .F.
    Private lMsErroAuto    := .F.
    Private lMsHelpAuto    := .T.
    Private lAutoErrNoFile := .T.

    cNum := GetSXENum("SC2", "C2_NUM")

    aAdd(aCab, {"C2_FILIAL" , xFilial("SC2")                     , Nil})
    aAdd(aCab, {"C2_NUM"    , cNum                               , Nil})
    aAdd(aCab, {"C2_ITEM"   , "01"                               , Nil})
    aAdd(aCab, {"C2_SEQUEN" , "001"                              , Nil})
    aAdd(aCab, {"C2_PRODUTO", cProduto                           , Nil})
    aAdd(aCab, {"C2_LOCAL"  , oPay["armazem"]                    , Nil})
    aAdd(aCab, {"C2_QUANT"  , oPay["quantidade"]                 , Nil})
    aAdd(aCab, {"C2_DATPRI" , SToD(StrTran(oPay["dataInicio"], "-", "")) , Nil})
    aAdd(aCab, {"C2_DATPRF" , SToD(StrTran(oPay["dataEntrega"], "-", "")), Nil})
    aAdd(aCab, {"C2_OBS"    , cObs                               , Nil})
    // Gera somente empenhos da OP solicitada; nunca abre OPs intermediarias ou SCs.
    aAdd(aCab, {"GERAOPI", "N", Nil})
    aAdd(aCab, {"GERASC", "N", Nil})
    aAdd(aCab, {"GERAEMP", "S", Nil})
    aAdd(aCab, {"AUTEXPLODE", "S"                                , Nil})

    bErroAnt := ErrorBlock({|oErr| cFalha := oErr:Description, Break(oErr)})
    Begin Sequence
        Begin Transaction
            MsExecAuto({|x, y| MATA650(x, y)}, aCab, 3)
            If lMsErroAuto
                DisarmTransaction()
            EndIf
        End Transaction
    Recover
        // Excecao no meio: nao sabemos o que ficou gravado.
        ErrorBlock(bErroAnt)
        RollBackSX8()
        Return {.F., .F., {}, "Erro inesperado na MATA650: " + cFalha + ;
                ". Confira a OP " + cNum + " no Protheus.", ""}
    End Sequence
    ErrorBlock(bErroAnt)

    If lMsErroAuto
        RollBackSX8()
        cLog := VFLogAuto()
        // So declara "sem efeito" se a OP realmente nao existe depois do rollback.
        lSemEfeito := !VFExisteOP(cNum)
        Return {.F., lSemEfeito, {}, "MATA650 recusou o pedido." + ;
                IIf(lSemEfeito, "", " Rollback NAO confirmado para a OP " + cNum + "."), cLog}
    EndIf

    ConfirmSX8()
    aRefs := VFRefsOP(cNum)
    lSucesso := Len(aRefs) > 0
Return {lSucesso, .F., aRefs, ;
        IIf(lSucesso, "MATA650 abriu a OP " + aRefs[1] + ".", ;
            "MATA650 nao informou erro, mas a OP " + cNum + " nao foi encontrada na SC2."), ;
        VFLogAuto()}

Static Function VFLogAuto()
    Local aLog := GetAutoGRLog()
    Local cLog := ""
    Local nI   := 0

    For nI := 1 To Len(aLog)
        cLog += aLog[nI] + CRLF
    Next nI
Return cLog

Static Function VFExisteOP(cNum)
    Local aArea := SC2->(GetArea())
    Local lAchou := .F.

    SC2->(DbSetOrder(1)) // C2_FILIAL+C2_NUM+C2_ITEM+C2_SEQUEN+C2_ITEMGRD
    lAchou := SC2->(DbSeek(xFilial("SC2") + cNum))
    RestArea(aArea)
Return lAchou

/*/ Retorna somente a OP solicitada, item 01 e sequencia 001. /*/
Static Function VFRefsOP(cNum)
    Local aArea := SC2->(GetArea())
    Local aRefs := {}

    SC2->(DbSetOrder(1))
    If SC2->(DbSeek(xFilial("SC2") + cNum + "01" + "001"))
        If SC2->C2_FILIAL == xFilial("SC2") .And. SC2->C2_NUM == cNum .And. ;
           SC2->C2_ITEM == "01" .And. SC2->C2_SEQUEN == "001" .And. ;
           Empty(SC2->C2_ITEMGRD) .And. !SC2->(Deleted())
            aAdd(aRefs, AllTrim(SC2->C2_NUM) + AllTrim(SC2->C2_ITEM) + AllTrim(SC2->C2_SEQUEN))
        EndIf
    EndIf
    RestArea(aArea)
Return aRefs
