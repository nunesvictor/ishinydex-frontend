import 'package:ishinydex/core/network/paginated.dart';
import 'package:ishinydex/features/personal_dex/domain/models.dart';

abstract interface class PersonalDexRepository {
  Future<List<PersonalDex>> fetchDexes();

  Future<PersonalDex> fetchDex(int dexId);

  /// Simula um dex com as formas de [recipe] (o conjunto padrão com as
  /// chaves do #34), sem criar nada.
  Future<DexPreview> previewNewDex({
    required DexRecipe recipe,
    required bool forceNewBox,
  });

  /// Cria um dex com as formas de [recipe] nas primeiras boxes livres e
  /// guarda a receita no dex. Sem [recipe], o conjunto padrão.
  Future<PersonalDex> createDex({
    required String name,
    required bool isShinyDex,
    required bool forceNewBox,
    DexRecipe recipe = const DexRecipe(),
  });

  /// O que mudou no padrão desde que o dex foi criado (#308), com o que
  /// cada jeito de atualizar faz nas boxes, e com as formas que saíram
  /// fora do dex ([dropRemoved]) ou mantidas. `null` sem mudança ou sem
  /// catálogo.
  Future<DexUpdatePreview?> previewDexUpdate(
    int dexId, {
    bool dropRemoved = true,
  });

  /// Traz o dex para o padrão de hoje, [mode]: na ordem ou no fim. Com
  /// [dropRemoved], as formas que saíram saem do dex, e os espécimes delas
  /// voltam ao inventário; senão, ficam.
  Future<PersonalDex> applyDexUpdate(
    int dexId, {
    required DexUpdateMode mode,
    required bool dropRemoved,
  });

  /// Guarda a decisão sobre a mudança [signature]: [ignore] = "Não
  /// atualizar" (some até o padrão mudar de novo); senão, "Agora não" (sai
  /// do topo e fica no menu).
  Future<PersonalDex> snoozeDexUpdate(
    int dexId, {
    required String signature,
    required bool ignore,
  });

  /// Renomeia o dex ou troca se é shiny dex (`force_new_box` não muda).
  Future<PersonalDex> updateDex(
    int dexId, {
    required String name,
    required bool isShinyDex,
  });

  /// Apaga o dex e libera os slots dele; os espécimes depositados continuam
  /// no inventário, disponíveis.
  Future<void> deleteDex(int dexId);

  Future<List<BoxSummary>> fetchBoxes(int dexId);

  /// Progresso por geração, na ordem em que as gerações aparecem nas boxes.
  Future<List<GenerationProgress>> fetchGenerations(int dexId);

  /// Os 30 slots de [boxId] pertencentes a [dexId].
  Future<List<Slot>> fetchSlots({required int dexId, required int boxId});

  Future<Slot> fetchSlot(int slotId);

  /// Slots de [dexId] cuja forma casa com [search]: nome ou número (Pokédex
  /// nacional ou o número mostrado no app). Primeiros resultados, na ordem
  /// das boxes.
  Future<List<Slot>> searchSlots({required int dexId, required String search});

  Future<Slot> deposit({required int slotId, required int specimenId});

  /// Tira o espécime do slot sem apagá-lo: ele volta ao inventário,
  /// disponível, e o slot fica faltante.
  Future<Slot> withdraw(int slotId);

  /// Slots de [dexId] com estas formas (onde cada uma está no dex).
  Future<List<Slot>> fetchSlotsByForms({
    required int dexId,
    required List<int> formIds,
  });

  /// Depositar automaticamente: espécimes livres nos slots vazios do dex,
  /// preferindo o brilho do dex; [strict] só aceita ele. Com [dryRun], só a
  /// prévia (nada é salvo).
  Future<LinkResult> linkSpecimens(
    int dexId, {
    bool strict = false,
    bool dryRun = false,
  });

  /// Uma página da lista de caçadas de um shiny dex, na ordem das boxes.
  Future<Paginated<Hunt>> fetchHunts(
    int dexId,
    HuntQuery query, {
    required int page,
    required int pageSize,
  });

  /// As boxes com itens na lista de caçadas (#282), na mesma ordem: a
  /// contagem de cada uma e o mapa dos slots, para os cabeçalhos.
  Future<List<HuntBox>> fetchHuntBoxes(int dexId, HuntQuery query);
}
