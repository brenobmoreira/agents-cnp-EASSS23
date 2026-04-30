!start.

+!start : num_servicos(I)
   <- .print("Iniciando ", I, " leiloes em paralelo...");
      
      ListaTarefas = ["calibrar_sensor", "lubrificar_esteira", "trocar_valvula", "inspecionar_motor", "ajustar_pressao", "limpar_filtro", "soldar_painel", "revisar_clp", "medir_temperatura", "transportar_peca"];
      
      .my_name(MeuNome);
      
      for ( .range(X, 1, I) ) {
          Idx = X - 1;
          .nth(Idx, ListaTarefas, TarefaBase);
         
          .concat(TarefaBase, "_", MeuNome, NomeServico);
          
          !!iniciar_leilao(NomeServico);
      }
      .

+!iniciar_leilao(Servico) 
   <- .system_time(TempoInicio);
      -+inicio_leilao(Servico, TempoInicio); // Grava na memoria a hora que começou
      .broadcast(tell, cfp(Servico));
      
      .wait(3000);
      
      !escolher_vencedor(Servico).

+propose(Servico, Preco)[source(Participante)] 
   <-
      true. 

+!escolher_vencedor(Servico)
   <- // --- 1. GARGALO DO RACIOCÍNIO BDI ---
      .system_time(TempoBDI_Inicio);
      
      .findall(proposta(Preco, Agente), propose(Servico, Preco)[source(Agente)], ListaPropostas);
      .length(ListaPropostas, RespostasRecebidas); // Conta quantas mensagens chegaram
      
      if (ListaPropostas == []) {
          .print("METRICA_CNP;", Servico, ";0;0;0");
      } else {
          .min(ListaPropostas, proposta(MenorPreco, Vencedor));
          
          .system_time(TempoBDI_Fim);
          TempoBDI = TempoBDI_Fim - TempoBDI_Inicio; // O tempo puro de varredura da memória
          
          // --- 2. CUSTO DE COMUNICAÇÃO (Overhead FIPA) ---
          .send(Vencedor, tell, accept_proposal(Servico));
          
          // Acha quem perdeu e manda FIPA Reject de uma vez só
          .findall(Ag, propose(Servico, _)[source(Ag)] & Ag \== Vencedor, ListaPerdedores);
          if (ListaPerdedores \== []) {
              .send(ListaPerdedores, tell, reject_proposal(Servico));
          }
          
          // --- 3. CONCORRÊNCIA DE INTENÇÕES (Tempo Total de Resolução) ---
          ?inicio_leilao(Servico, TempoInicio);
          .system_time(TempoFim);
          TempoTotal = TempoFim - TempoInicio;
          
          .abolish(propose(Servico, _));
          
          // METRICA_CNP ; Servico ; RespostasRecebidas ; TempoBDI ; TempoTotal
          .print("METRICA_CNP;", Servico, ";", RespostasRecebidas, ";", TempoBDI, ";", TempoTotal);
      }
      .