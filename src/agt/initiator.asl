!start.

+!start 
   <- ?num_servicos(I); 
      .print("Iniciando ", I, " leiloes em paralelo...");
      
      ListaTarefas = ["calibrar_sensor", "lubrificar_esteira", "trocar_valvula", "inspecionar_motor", "ajustar_pressao", "limpar_filtro", "soldar_painel", "revisar_clp", "medir_temperatura", "transportar_peca"];
      
      .my_name(MeuNome);
      
      for ( .range(X, 1, I) ) {
          Idx = X - 1;
          .nth(Idx, ListaTarefas, TarefaBase);
         
          .concat(TarefaBase, "_", MeuNome, NomeServico);
          
          !!iniciar_leilao(NomeServico);
      }
      .

-!start 
   <- .print("ERRO FATAL: Nao encontrei a crenca num_servicos!").

+!iniciar_leilao(Servico) 
   <- .time(H, M, S, MS);
   TempoInicio = (H * 3600000) + (M * 60000) + (S * 1000) + MS;
      .broadcast(tell, cfp(Servico));
      
      .wait(3000);
      
      !escolher_vencedor(Servico, TempoInicio).

+propose(Servico, Preco)[source(Participante)] 
   <-
      true. 

+!escolher_vencedor(Servico, TempoInicio)
   <- // --- 1. GARGALO DO RACIOCÍNIO BDI ---
   .time(H1, M1, S1, MS1);
   TempoBDI_Inicio = (H1 * 3600000) + (M1 * 60000) + (S1 * 1000) + MS1;
      
      .findall(proposta(Preco, Agente), propose(Servico, Preco)[source(Agente)], ListaPropostas);
      .length(ListaPropostas, RespostasRecebidas); // Conta quantas mensagens chegaram
      
      if (ListaPropostas == []) {
          .print("METRICA_CNP;", Servico, ";0;0;0");
      } else {
          .min(ListaPropostas, proposta(MenorPreco, Vencedor));
          
          .time(H2, M2, S2, MS2);
          TempoBDI_Fim = (H2 * 3600000) + (M2 * 60000) + (S2 * 1000) + MS2;
          TempoBDI = TempoBDI_Fim - TempoBDI_Inicio; // O tempo puro de varredura da memória
          
          // --- 2. CUSTO DE COMUNICAÇÃO (Overhead FIPA) ---
          .send(Vencedor, tell, accept_proposal(Servico));
          
          // Acha quem perdeu e manda FIPA Reject de uma vez só
          .findall(Ag, propose(Servico, _)[source(Ag)] & Ag \== Vencedor, ListaPerdedores);
          if (ListaPerdedores \== []) {
              .send(ListaPerdedores, tell, reject_proposal(Servico));
          }
          
          // --- 3. CONCORRÊNCIA DE INTENÇÕES (Tempo Total de Resolução) ---
          .time(H3, M3, S3, MS3);
           TempoFim = (H3 * 3600000) + (M3 * 60000) + (S3 * 1000) + MS3;
           TempoTotal = TempoFim - TempoInicio;
          
          .abolish(propose(Servico, _));
          
          // METRICA_CNP ; Servico ; RespostasRecebidas ; TempoBDI ; TempoTotal
          .print("METRICA_CNP;", Servico, ";", RespostasRecebidas, ";", TempoBDI, ";", TempoTotal);
      }
      .