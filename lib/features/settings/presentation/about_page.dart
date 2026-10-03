import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ishinydex/core/config/env.dart';
import 'package:ishinydex/features/catalog/catalog_providers.dart';

/// Endereço do código, mostrado (selecionável) em "Sobre".
const projectUrl = 'https://github.com/nunesvictor/ishinydex';

const _demoData =
    'Esta é uma demonstração: os dados são fictícios, ficam só na memória '
    'do navegador e somem ao recarregar a página.';
const _demoNothingSent = 'Nada do que você faz aqui é enviado a lugar nenhum.';
const _localData =
    'Seus dados ficam neste aparelho, no armazenamento do navegador (no '
    'iPhone e no iPad, no do app instalado na Tela de Início). Quem mantém o '
    'projeto não recebe nem guarda nada.';

String _serverData(String url) =>
    'Seus dados ficam no servidor configurado ($url). Quem mantém o projeto '
    'não recebe nem guarda nada.';

const _trademarks =
    'Pokémon e os nomes, imagens e marcas relacionados são propriedade da '
    'Nintendo, Creatures, GAME FREAK e The Pokémon Company.';
const _fanProject =
    'O iShinyDex é um projeto de fã, gratuito e sem fins lucrativos, sem '
    'afiliação com essas empresas.';
const _sources =
    'Dados e sprites vêm da PokéAPI (pokeapi.co). Os ícones de shiny, alfa e '
    'marcas de origem do Pokémon HOME vêm da Bulbagarden Archives.';

/// Ajustes → Sobre o iShinyDex: versão, privacidade e aviso legal.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(envProvider);
    final theme = Theme.of(context);
    Widget section(String title, List<String> paragraphs) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          for (final text in paragraphs)
            Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o iShinyDex')),
      body: Center(
        child: ConstrainedBox(
          // Texto corrido: linhas longas demais cansam a leitura no PC.
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome, size: 40),
                title: const Text('iShinyDex'),
                subtitle: Text('Versão ${env.appVersion}'),
              ),
              const SelectableText(projectUrl),
              if (ref.watch(catalogLoadProvider) case final load?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Catálogo ${load.catalog.version} · carregado em '
                    '${load.elapsed.inMilliseconds} ms',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 24),
              section('Privacidade', [
                if (env.localData)
                  _localData
                else if (env.useFakeApi) ...[
                  _demoData,
                  _demoNothingSent,
                ] else
                  _serverData(env.apiBaseUrl),
              ]),
              section('Aviso legal', [_trademarks, _fanProject, _sources]),
            ],
          ),
        ),
      ),
    );
  }
}
