#Include "TOTVS.ch"

/*/{Protheus.doc} VFEMP01
Exclusao seletiva de empenhos via MATA381 (alteracao, LINPOS + AUTDELETA).
Chamado pelo consumidor VFFILA01 depois da reserva exclusiva.
Nao compilado/homologado: validar no RPO DEV antes de liberar execucao.
Retorno: {sucesso, semEfeito, referencias, mensagem, logExecauto}.
/*/
User Function VFEMP01(oPed)
    Local aArea    := GetArea()
    Local aSD4     := SD4->(GetArea())
    Local aSC2     := SC2->(GetArea())
    Local oPay     := oPed["payload"]
    Local cOp      := oPay["op"]
    Local aCab     := {}
    Local aItens   := {}
    Local aLine    := {}
    Local aLog     := {}
    Local cLog     := ""
    Local cFalha   := ""
    Local bErroAnt := Nil
    Local nI       := 0
    Local nF       := 0
    Local lOk      := .F.
    Local lExecutou := .F.
    Local lSemEfeito := .F.
    Local aLocks   := {}
    Local nSC2Lock := 0
    Private lMsErroAuto := .F.
    Private lMsHelpAuto := .T.
    Private lAutoErrNoFile := .T.

    If oPed["operacao"] != "exclusao_empenhos" .Or. ;
       AllTrim(cEmpAnt) != "01" .Or. AllTrim(cFilAnt) != "04" .Or. ;
       (Upper(AllTrim(GetEnvServer())) != "P12DEV" .And. Upper(AllTrim(GetEnvServer())) != "P12REST")
        Return {.F., .T., {}, "Executor restrito a empenhos do DEV, grupo 01 / filial 04.", ""}
    EndIf
    If Len(oPay["excluded"]) == 0
        Return {.F., .T., {}, "Nenhuma linha selecionada.", ""}
    EndIf

    For nI := 1 To Len(oPay["excluded"])
        If aScan(oPay["snapshot"]["items"], {|r| r["id"] == oPay["excluded"][nI]["id"]}) == 0 .Or. ;
           aScan(oPay["excluded"], {|r| r["id"] == oPay["excluded"][nI]["id"]}) != nI
            Return {.F., .T., {}, "Selecao invalida ou duplicada.", ""}
        EndIf
    Next nI

    bErroAnt := ErrorBlock({|oErr| cFalha := oErr:Description, Break(oErr)})
    Begin Transaction
        Begin Sequence
            // Confere identidade e estado da OP, incluindo produto e emissao.
            If !VEConfere(oPay, .F.)
                cFalha := "A OP mudou ou esta encerrada. Revise novamente no VettiFlow."
            ElseIf !RecLock("SC2", .F.)
                cFalha := "OP em uso. Nenhuma exclusao executada."
            Else
                nSC2Lock := SC2->(RecNo())
                // RecNo sozinho nunca identifica uma linha: confronta todos os campos.
                For nI := 1 To Len(oPay["snapshot"]["items"])
                    SD4->(DbGoTo(oPay["snapshot"]["items"][nI]["id"]))
                    If !RecLock("SD4", .F.)
                        cFalha := "Empenho em uso. Nenhuma exclusao executada."
                        Exit
                    EndIf
                    aAdd(aLocks, SD4->(RecNo()))
                Next nI
                If Empty(cFalha) .And. !VEConfere(oPay, .F.)
                    cFalha := "Os empenhos mudaram desde a revisao. Nenhuma exclusao executada."
                EndIf
                If Empty(cFalha)
                    For nI := 1 To Len(oPay["excluded"])
                        SD4->(DbGoTo(oPay["excluded"][nI]["id"]))
                        If Left(Upper(AllTrim(SD4->D4_COD)), 3) == "MOD" .Or. SD4->D4_QUANT <= 0
                            cFalha := "MOD ou empenho sem saldo nao pode ser excluido por este fluxo."
                            Exit
                        EndIf
                        aLine := {}
                        For nF := 1 To SD4->(FCount())
                            If Left(SD4->(FieldName(nF)), 3) == "D4_"
                                aAdd(aLine, {SD4->(FieldName(nF)), SD4->(FieldGet(nF)), Nil})
                            EndIf
                        Next nF
                        aAdd(aLine, {"LINPOS", "D4_COD+D4_TRT+D4_LOTECTL+D4_NUMLOTE+D4_LOCAL+D4_OPORIG+D4_SEQ", ;
                            SD4->D4_COD, SD4->D4_TRT, SD4->D4_LOTECTL, SD4->D4_NUMLOTE, ;
                            SD4->D4_LOCAL, SD4->D4_OPORIG, SD4->D4_SEQ})
                        aAdd(aLine, {"AUTDELETA", "S", Nil})
                        aAdd(aItens, aLine)
                    Next nI
                EndIf
                If Empty(cFalha)
                    aCab := {{"D4_OP", PadR(cOp, TamSX3("D4_OP")[1]), Nil}, {"INDEX", 2, Nil}}
                    // Opcao 4 altera somente as linhas enviadas. NUNCA usar opcao 5 (OP inteira).
                    lExecutou := .T.
                    MsExecAuto({|x, y, z| MATA381(x, y, z)}, aCab, aItens, 4)
                    If lMsErroAuto
                        cFalha := "MATA381 recusou a exclusao."
                    ElseIf !VEConfere(oPay, .T.)
                        cFalha := "Resultado divergiu da selecao; transacao desfeita."
                    Else
                        lOk := .T.
                    EndIf
                EndIf
            EndIf
        Recover
            lOk := .F.
        End Sequence
        If !lOk
            DisarmTransaction()
        EndIf
    End Transaction
    ErrorBlock(bErroAnt)

    // Libera os locks adquiridos por este executor, inclusive depois de erro.
    For nI := 1 To Len(aLocks)
        SD4->(DbGoTo(aLocks[nI]))
        SD4->(MsUnlock())
    Next nI
    If nSC2Lock > 0
        SC2->(DbGoTo(nSC2Lock))
        SC2->(MsUnlock())
    EndIf
    If lExecutou
        aLog := GetAutoGRLog()
    EndIf
    For nI := 1 To Len(aLog)
        cLog += aLog[nI] + CRLF
    Next nI
    // Conferencia adicional apos commit/rollback. Incerteza nunca autoriza repeticao.
    If lOk
        lOk := VEConfere(oPay, .T.)
        If !lOk
            cFalha := "Nao foi possivel confirmar o resultado apos commit. Confira no Protheus."
        EndIf
    ElseIf !lExecutou
        lSemEfeito := .T. // Validacao recusou antes de qualquer rotina de escrita.
    Else
        lSemEfeito := VEConfere(oPay, .F.)
    EndIf
    RestArea(aSD4)
    RestArea(aSC2)
    RestArea(aArea)
Return {lOk, lSemEfeito, IIf(lOk, {cOp}, {}), ;
        IIf(lOk, "Empenhos selecionados excluidos pela MATA381; demais linhas preservadas.", cFalha), cLog}

Static Function VEOrdem(oPay)
    Local oOrd := oPay["snapshot"]["order"]
    Local cKey := xFilial("SC2") + PadR(oOrd["numeroBase"], TamSX3("C2_NUM")[1]) + ;
                  PadR(oOrd["item"], TamSX3("C2_ITEM")[1]) + ;
                  PadR(oOrd["sequencia"], TamSX3("C2_SEQUEN")[1]) + ;
                  PadR(oOrd["itemGrade"], TamSX3("C2_ITEMGRD")[1])
    Local cEmissao := StrTran(Left(oOrd["emissao"], 10), "-", "")
    If "/" $ oOrd["emissao"]
        cEmissao := SubStr(oOrd["emissao"], 7, 4) + SubStr(oOrd["emissao"], 4, 2) + Left(oOrd["emissao"], 2)
    EndIf
    SC2->(DbSetOrder(1))
    If !SC2->(DbSeek(cKey)) .Or. SC2->(Deleted())
        Return .F.
    EndIf
Return SC2->C2_FILIAL == xFilial("SC2") .And. ;
       AllTrim(SC2->C2_NUM)+AllTrim(SC2->C2_ITEM)+AllTrim(SC2->C2_SEQUEN)+AllTrim(SC2->C2_ITEMGRD) == oPay["op"] .And. ;
       AllTrim(SC2->C2_PRODUTO) == oOrd["produto"] .And. ;
       AllTrim(SC2->C2_LOCAL) == oOrd["local"] .And. ;
       DToS(SC2->C2_EMISSAO) == cEmissao .And. Empty(SC2->C2_DATRF) .And. ;
       SC2->C2_QUANT == oOrd["quantidadePlanejada"] .And. SC2->C2_QUJE == oOrd["quantidadeProduzida"]

Static Function VELinha(oRow)
Return SD4->(RecNo()) == oRow["id"] .And. ;
       AllTrim(SD4->D4_COD) == oRow["produto"] .And. AllTrim(SD4->D4_LOCAL) == oRow["local"] .And. ;
       SD4->D4_QUANT == oRow["quantidade"] .And. SD4->D4_QTDEORI == oRow["quantidadeOriginal"] .And. ;
       AllTrim(SD4->D4_TRT) == oRow["tratamento"] .And. AllTrim(SD4->D4_LOTECTL) == oRow["loteControle"] .And. ;
       AllTrim(SD4->D4_NUMLOTE) == oRow["numeroLote"] .And. AllTrim(SD4->D4_OPORIG) == oRow["opOrigem"] .And. ;
       AllTrim(SD4->D4_SEQ) == oRow["sequencia"]

Static Function VEConfere(oPay, lDepois)
    Local aRows := oPay["snapshot"]["items"]
    Local aExc  := oPay["excluded"]
    Local cOp   := PadR(oPay["op"], TamSX3("D4_OP")[1])
    Local nPos  := 0
    Local nRec  := 0
    Local nCount := 0
    Local lExcluir := .F.

    If !VEOrdem(oPay)
        Return .F.
    EndIf
    SD4->(DbSetOrder(2))
    SD4->(DbSeek(xFilial("SD4") + cOp))
    While !SD4->(Eof()) .And. SD4->D4_FILIAL == xFilial("SD4") .And. SD4->D4_OP == cOp
        If !SD4->(Deleted())
            nRec := SD4->(RecNo())
            nPos := aScan(aRows, {|r| r["id"] == nRec})
            lExcluir := aScan(aExc, {|r| r["id"] == nRec}) > 0
            If nPos == 0
                Return .F.
            EndIf
            If (lDepois .And. lExcluir) .Or. !VELinha(aRows[nPos])
                Return .F.
            EndIf
            nCount++
        EndIf
        SD4->(DbSkip())
    EndDo
Return nCount == Len(aRows) - IIf(lDepois, Len(aExc), 0)
