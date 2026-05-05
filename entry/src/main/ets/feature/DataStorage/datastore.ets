/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// [Start persistence_get_store]
import { relationalStore } from '@kit.ArkData'; // 导入模块
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UIContext } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
export interface ArticleEntry{
  title: string;
  date: string;
  type: string;
}

/**
 * 笔记数据库条目（用于 ARTICLE 类型）
 */
export interface NoteEntry {
  id?: number;          // 数据库主键ID
  title: string;
  date: string;
  type: string;
  filePath: string;     // 文件完整路径
  noteId: string;       // 笔记ID（文件名不含.json）
}
const DOMAIN = 0x0000;

let store: relationalStore.RdbStore | undefined = undefined;
let dbInitPromise: Promise<void> | undefined = undefined; // 缓存初始化 Promise
let appContext: common.UIAbilityContext | undefined = undefined; // 全局应用上下文
let tokenType = relationalStore.Tokenizer.ICU_TOKENIZER;
let tokenTypeSupported = relationalStore.isTokenizerSupported(tokenType);
if (!tokenTypeSupported) {
  tokenType = relationalStore.Tokenizer.NONE_TOKENIZER;
  hilog.error(DOMAIN, 'rdbDataPersistence', `ICU_TOKENIZER is not supported on this platform.`);
}

const STORE_CONFIG: relationalStore.StoreConfig = {
  // 数据库文件名
  name: 'RdbTest.db',
  // 数据库安全级别
  securityLevel: relationalStore.SecurityLevel.S3,
  // 可选参数，指定数据库是否加密，默认不加密
  encrypt: false,
  // 可选参数，数据库自定义路径。默认在本应用沙箱目录下创建RdbStore实例。
  customDir: 'customDir/subCustomDir',
  // 可选参数，指定数据库是否以只读方式打开。默认为false，表示数据库可读可写。为true时，只允许从数据库读取数据，不允许对数据库进行写操作，否则会返回错误码801。
  isReadOnly: false,
  // 可选参数，指定用户在全文搜索场景(FTS)下使用哪种分词器。默认在FTS下仅支持英文分词，不支持其他语言分词。
  tokenizer: tokenType,
};

/**
 * 手动初始化数据库（推荐在 EntryAbility 中调用）
 */
export function initDb(context: common.UIAbilityContext): void {
  appContext = context;
  console.info(`[datastore] initDb 已设置 appContext，触发后台初始化`);
  ensureDbReady();
}

/**
 * 内部数据库初始化逻辑
 */
async function initDatabase(): Promise<void> {
  console.info(`[datastore] 开始初始化数据库`);
  if (!appContext) {
    console.error(`[datastore] 初始化失败: appContext 未提供`);
    return;
  }
  const SQL_CREATE_TABLE = 'CREATE TABLE IF NOT EXISTS ARTICLE (ID INTEGER PRIMARY KEY AUTOINCREMENT, TITLE TEXT NOT NULL, TIME DATE,TYPE TEXT)';
  const SQL_CREATE_NOTES_TABLE = 'CREATE TABLE IF NOT EXISTS NOTES (ID INTEGER PRIMARY KEY AUTOINCREMENT, TITLE TEXT NOT NULL, TIME DATE, TYPE TEXT, FILE_PATH TEXT NOT NULL, NOTE_ID TEXT NOT NULL)';
  
  try {
    console.info(`[datastore] 调用 getRdbStore`);
    store = await relationalStore.getRdbStore(appContext, STORE_CONFIG);
    console.info(`[datastore] RdbStore 获取成功`);
  } catch (e) {
    const err = e as BusinessError;
    console.error(`[datastore] RdbStore 获取失败: Code=${err.code}, message=${err.message}`);
    return;
  }

  if (store) {
    try {
      const transaction = await store.createTransaction({});
      const storeVersion = await transaction.execute('PRAGMA user_version');
      console.info(`[datastore] 当前数据库版本: ${storeVersion}`);
      
      // 无论版本如何，都确保表存在（修复表不存在问题）
      console.info(`[datastore] 创建/检查数据表`);
      await transaction.execute(SQL_CREATE_TABLE);
      await transaction.execute(SQL_CREATE_NOTES_TABLE);
      
      if (storeVersion === 0) {
        await transaction.execute('PRAGMA user_version = 1');
        console.info(`[datastore] 数据库版本已更新为 1`);
      }
      await transaction.commit();
      console.info(`[datastore] 数据库初始化完成`);
    } catch (e) {
      const err = e as BusinessError;
      console.error(`[datastore] 建表失败: Code=${err.code}, message=${err.message}`);
    }
  }
}

/**
 * 确保数据库已就绪（全局守卫，内部自动调用）
 */
export async function ensureDbReady(): Promise<void> {
  if (store !== undefined) return; // 已就绪，直接返回
  if (dbInitPromise === undefined) {
    dbInitPromise = initDatabase(); // 启动初始化
  }
  await dbInitPromise; // 等待初始化完成
}

/**
 * 获取数据库实例（兼容旧接口，App 启动时调用）
 */
export async function getDataBase(): Promise<void> {
  return ensureDbReady();
}

export async function InsertArticle(title:string,time:string,type:string) {
  // [Start persistence_insert_data]
  // 插入数据
  const valueBucket: relationalStore.ValuesBucket = {
    TITLE: title,
    TIME: time,
    TYPE: type,
  };
  if (store !== undefined) {
    try {
      const rowId = await store.insert('ARTICLE', valueBucket);
      hilog.info(DOMAIN, 'rdbDataPersistence', `Succeeded in inserting data. rowId:${rowId}`);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to insert data. Code:${err.code}, message:${err.message}`);
    }
  }
  // [End persistence_insert_data]
}

export async function UpdateArticle(oldTitle:string,newTitle:string, time:string,type:string){
  // [Start persistence_update_and_delete_data]
  // 修改数据、删除数据
  const valueBucket2: relationalStore.ValuesBucket = {
    TITLE: newTitle,
    TIME: time,
    TYPE: type,
  };

  // 修改数据
  let predicates1 = new relationalStore.RdbPredicates('ARTICLE');
  predicates1.equalTo('TITLE', oldTitle);
  if (store !== undefined) {
    (store as relationalStore.RdbStore).update(valueBucket2, predicates1, (err: BusinessError, rows: number) => {
      if (err) {
        hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to update data. Code:${err.code}, message:${err.message}`);
        return;
      }
      hilog.info(DOMAIN, 'rdbDataPersistence', `Succeeded in updating data. row count: ${rows}`);
    })
  }
}

export async function DeleteArticle(title:string){
  // 删除数据
  let predicates1 = new relationalStore.RdbPredicates('ARTICLE');
  predicates1.equalTo('TITLE', title);
  if (store !== undefined) {
    (store as relationalStore.RdbStore).delete(predicates1, (err: BusinessError, rows: number) => {
      if (err) {
        hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to delete data. Code:${err.code}, message:${err.message}`);
        return;
      }
      hilog.info(DOMAIN, 'rdbDataPersistence', `Delete rows: ${rows}`);
    })
  }
  // [End persistence_update_and_delete_data]
}

export async function QueryArticle(title:string){
  // [Start persistence_query_data]
  // 查找数据
  let predicates2 = new relationalStore.RdbPredicates('ARTICLE');
  predicates2.equalTo('TITLE', title);
  if (store !== undefined) {
    (store as relationalStore.RdbStore).query(predicates2, ['ID', 'TITLE', 'TIME', 'TYPE'],
      (err: BusinessError, resultSet) => {
        if (err) {
          hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to query data. Code:${err.code}, message:${err.message}`);
          return;
        }
        hilog.info(DOMAIN, 'rdbDataPersistence',
          `ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
        // resultSet是一个数据集合的游标，默认指向第-1个记录，有效的数据从0开始。
        while (resultSet.goToNextRow()) {
          const title = resultSet.getString(resultSet.getColumnIndex('TITLE'));
          const time = resultSet.getString(resultSet.getColumnIndex('TIME'));
          const type = resultSet.getString(resultSet.getColumnIndex('TYPE'));
          hilog.info(DOMAIN, 'rdbDataPersistence',
            `title=${title}, time=${time}, type=${type}`);
        }
        // 释放数据集的内存
        resultSet.close();
      })
  }
  // [End persistence_query_data]
}

// [StartExclude persistence_get_store]
export async function rdbDataPersistence() {

  // [Start persistence_chinese_query_data]
  // 中文关键字检索，查找数据
  // if (store !== undefined && tokenTypeSupported) {
  //   // 创建全文检索表
  //   const SQL_CREATE_TABLE = 'CREATE VIRTUAL TABLE IF NOT EXISTS example USING fts4(name, content, tokenize=icu zh_CN)';
  //   try {
  //     await store.execute(SQL_CREATE_TABLE);
  //     hilog.info(DOMAIN, 'rdbDataPersistence', 'Succeeded in creating fts table.');
  //   } catch (error) {
  //     const err = error as BusinessError;
  //     hilog.error(DOMAIN, 'rdbDataPersistence',
  //       `Failed to creating fts table. code: ${err.code}, message: ${err.message}.`);
  //   }
  // }
  // if (store !== undefined) {
  //   try {
  //     const resultSet = await store.querySql('SELECT name FROM example WHERE example MATCH ?', ['测试']);
  //     while (resultSet.goToNextRow()) {
  //       const name = resultSet.getValue(resultSet.getColumnIndex('name'));
  //       hilog.info(DOMAIN, 'rdbDataPersistence', `name=${name}`);
  //     }
  //     resultSet.close();
  //   } catch (error) {
  //     const err = error as BusinessError;
  //     hilog.error(DOMAIN, 'rdbDataPersistence', `Query failed. code: ${err.code}, message: ${err.message}.`);
  //   }
  // }
  // [End persistence_chinese_query_data]

  // [Start persistence_transaction_insert_update_and_delete_data]
  // 使用事务对象执行数据的插入、删除和更新操作
  // if (store !== undefined) {
  //   // 创建事务对象
  //   try {
  //     const transaction = await store.createTransaction();
  //     try {
  //       // 使用事务对象插入数据
  //       const rowId = await transaction.insert(
  //         'EMPLOYEE',
  //         {
  //           NAME: 'Lisa',
  //           AGE: 18,
  //           SALARY: 100.5,
  //           CODES: new Uint8Array([1, 2, 3, 4, 5]),
  //           IDENTITY: BigInt('15822401018187971967763')
  //         },
  //         relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
  //       );
  //       hilog.info(DOMAIN, 'rdbDataPersistence', `Insert is successful, rowId = ${rowId}`);
  //
  //       const predicates = new relationalStore.RdbPredicates('EMPLOYEE');
  //       predicates.equalTo('NAME', 'Lisa');
  //       // 使用事务对象更新数据
  //       const rows = await transaction.update(
  //         {
  //           NAME: 'Rose',
  //           AGE: 22,
  //           SALARY: 200.5,
  //           CODES: new Uint8Array([1, 2, 3, 4, 5]),
  //           IDENTITY: BigInt('15822401018187971967763')
  //         },
  //         predicates,
  //         relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
  //       );
  //       hilog.info(DOMAIN, 'rdbDataPersistence', `Updated row count: ${rows}`);
  //
  //       // 使用事务对象删除数据
  //       await transaction.execute('DELETE FROM EMPLOYEE WHERE age = ? OR age = ?', [21, 20]);
  //       hilog.info(DOMAIN, 'rdbDataPersistence', `execute delete success`);
  //
  //       // 提交事务
  //       await transaction.commit();
  //       hilog.info(DOMAIN, 'rdbDataPersistence', 'Transaction commit success.');
  //     } catch (error) {
  //       const err = error as BusinessError;
  //       // 执行失败回滚事务
  //       await transaction.rollback();
  //       hilog.error(DOMAIN, 'rdbDataPersistence',
  //         `Transaction execute failed, code is ${err.code}, message is ${err.message}`);
  //     }
  //   } catch (error) {
  //     const err = error as BusinessError;
  //     hilog.error(DOMAIN, 'rdbDataPersistence',
  //       `createTransaction failed, code is ${err.code}, message is ${err.message}`);
  //   }
  // }
  // [End persistence_transaction_insert_update_and_delete_data]

  // [Start persistence_backup_store]
  // 在同路径下备份数据库
  if (store !== undefined) {
    // 'Backup.db'为备份数据库文件名，默认在RdbStore同路径下备份。也可指定路径：customDir + 'Backup.db'
    (store as relationalStore.RdbStore).backup('Backup.db', (err: BusinessError) => {
      if (err) {
        hilog.error(DOMAIN, 'rdbDataPersistence',
          `Failed to backup RdbStore. Code:${err.code}, message:${err.message}`);
        return;
      }
      hilog.info(DOMAIN, 'rdbDataPersistence', `Succeeded in backing up RdbStore.`);
    })
  }
  // [End persistence_backup_store]

  // [Start persistence_restore]
  // 备份数据库中恢复数据
  if (store !== undefined) {
    (store as relationalStore.RdbStore).restore('Backup.db', (err: BusinessError) => {
      if (err) {
        hilog.error(DOMAIN, 'rdbDataPersistence',
          `Failed to restore RdbStore. Code:${err.code}, message:${err.message}`);
        return;
      }
      hilog.info(DOMAIN, 'rdbDataPersistence', `Succeeded in restoring RdbStore.`);
    })
  }
  // [End persistence_restore]

  // [Start persistence_delete_store]
  // 删除数据库
  // const context = new UIContext().getHostContext() as common.UIAbilityContext;
  // relationalStore.deleteRdbStore(context, 'RdbTest.db', (err: BusinessError) => {
  //   if (err) {
  //     hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to delete RdbStore. Code:${err.code}, message:${err.message}`);
  //     return;
  //   }
  //   hilog.info(DOMAIN, 'rdbDataPersistence', 'Succeeded in deleting RdbStore.');
  // });
  // [End persistence_delete_store]
}

export async function LinkTable(){
  if (store === undefined) {
    try {
      const context = new UIContext().getHostContext() as common.UIAbilityContext;
      store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to get RdbStore. Code:${err.code}, message:${err.message}`);
      return;
    }
  }
}

export async function getArticles():Promise<ArticleEntry[]>{
  let entries:ArticleEntry[] = [];
  let predicates2 = new relationalStore.RdbPredicates('ARTICLE');
  predicates2.equalTo('TITLE', '从一到二的笔记库开发');
  if (store !== undefined) {
    (store as relationalStore.RdbStore).query(predicates2, ['ID', 'TITLE', 'TIME', 'TYPE'],
      (err: BusinessError, resultSet) => {
        if (err) {
          hilog.error(DOMAIN, 'rdbDataPersistence', `Failed to query data. Code:${err.code}, message:${err.message}`);
          return;
        }
        hilog.info(DOMAIN, 'rdbDataPersistence',
          `ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
        // resultSet是一个数据集合的游标，默认指向第-1个记录，有效的数据从0开始。
        while (resultSet.goToNextRow()) {

          const title = resultSet.getString(resultSet.getColumnIndex('TITLE'));
          const time = resultSet.getString(resultSet.getColumnIndex('TIME'));
          const type = resultSet.getString(resultSet.getColumnIndex('TYPE'));
          entries.push({title:title,date:time, type:type} as ArticleEntry);
          hilog.info(DOMAIN, 'rdbDataPersistence',
            `title=${title}, time=${time}, type=${type}`);
        }
        // 释放数据集的内存
        resultSet.close();
      })
  }
  return entries;
}

/**
 * 按时间从后到先（降序）查询所有文章
 * @param limit 可选，限制返回数量
 * @returns 文章列表，按时间倒序排列
 */
export async function getArticlesByTimeDesc(limit?: number): Promise<ArticleEntry[]> {
  let entries: ArticleEntry[] = [];

  // 创建查询条件，不添加过滤条件以查询所有数据
  let predicates = new relationalStore.RdbPredicates('ARTICLE');

  // 按 TIME 字段降序排列（最新的在前）
  predicates.orderByDesc('TIME');

  if (store !== undefined) {
    try {
      const resultSet = await store.query(predicates, ['ID', 'TITLE', 'TIME', 'TYPE']);

      hilog.info(DOMAIN, 'rdbDataPersistence',
        `ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);

      // 遍历所有结果
      while (resultSet.goToNextRow()) {
        const title = resultSet.getString(resultSet.getColumnIndex('TITLE'));
        const time = resultSet.getString(resultSet.getColumnIndex('TIME'));
        const type = resultSet.getString(resultSet.getColumnIndex('TYPE'));

        entries.push({ title: title, date: time, type: type } as ArticleEntry);

        hilog.info(DOMAIN, 'rdbDataPersistence',
          `title=${title}, time=${time}, type=${type}`);
      }

      // 释放数据集的内存
      resultSet.close();

    } catch (error) {
      const err = error as BusinessError;
      hilog.error(DOMAIN, 'rdbDataPersistence',
        `Failed to query articles by time desc. Code:${err.code}, message:${err.message}`);
    }
  }

  return entries;
}

// ==================== NOTES 表操作（ARTICLE 类型笔记专用）====================

/**
 * 插入笔记记录到数据库
 * @param note 笔记条目
 * @returns 插入的行 ID
 */
export async function InsertNote(note: NoteEntry): Promise<number | undefined> {
  await ensureDbReady();
  if (store === undefined) return undefined;
  
  console.info(`[datastore] InsertNote 开始: title=${note.title}, filePath=${note.filePath}, noteId=${note.noteId}`);
  
  const valueBucket: relationalStore.ValuesBucket = {
    TITLE: note.title,
    TIME: note.date,
    TYPE: note.type,
    FILE_PATH: note.filePath,
    NOTE_ID: note.noteId,
  };

  console.info(`[datastore] InsertNote valueBucket: ${JSON.stringify(valueBucket)}`);

  try {
    const rowId = await store.insert('NOTES', valueBucket);
    console.info(`[datastore] InsertNote 成功! rowId=${rowId}`);
    hilog.info(DOMAIN, 'datastore', `Succeeded in inserting note. rowId:${rowId}`);
    return rowId;
  } catch (error) {
    const err = error as BusinessError;
    console.error(`[datastore] InsertNote 失败: Code=${err.code}, message=${err.message}`);
    hilog.error(DOMAIN, 'datastore', `Failed to insert note. Code:${err.code}, message:${err.message}`);
    return undefined;
  }
}

/**
 * 更新笔记记录
 * @param id 数据库主键 ID
 * @param note 笔记条目
 */
export async function UpdateNote(id: number, note: NoteEntry): Promise<boolean> {
  await ensureDbReady();
  if (store === undefined) return false;
  
  const valueBucket: relationalStore.ValuesBucket = {
    TITLE: note.title,
    TIME: note.date,
    TYPE: note.type,
    FILE_PATH: note.filePath,
    NOTE_ID: note.noteId,
  };

  let predicates = new relationalStore.RdbPredicates('NOTES');
  predicates.equalTo('ID', id);

  try {
    const rows = await store.update(valueBucket, predicates);
    hilog.info(DOMAIN, 'datastore', `Succeeded in updating note. row count: ${rows}`);
    return rows > 0;
  } catch (error) {
    const err = error as BusinessError;
    hilog.error(DOMAIN, 'datastore', `Failed to update note. Code:${err.code}, message:${err.message}`);
    return false;
  }
}

/**
 * 删除笔记记录
 * @param id 数据库主键 ID
 */
export async function DeleteNote(id: number): Promise<boolean> {
  await ensureDbReady();
  if (store === undefined) return false;
  
  let predicates = new relationalStore.RdbPredicates('NOTES');
  predicates.equalTo('ID', id);

  try {
    const rows = await store.delete(predicates);
    hilog.info(DOMAIN, 'datastore', `Deleted note rows: ${rows}`);
    return rows > 0;
  } catch (error) {
    const err = error as BusinessError;
    hilog.error(DOMAIN, 'datastore', `Failed to delete note. Code:${err.code}, message:${err.message}`);
    return false;
  }
}

/**
 * 根据笔记 ID（文件名）查询笔记
 * @param noteId 笔记 ID（不含.json）
 * @returns 笔记条目或 undefined
 */
export async function QueryNoteByNoteId(noteId: string): Promise<NoteEntry | undefined> {
  await ensureDbReady();
  if (store === undefined) return undefined;
  
  let predicates = new relationalStore.RdbPredicates('NOTES');
  predicates.equalTo('NOTE_ID', noteId);

  try {
    const resultSet = await store.query(predicates, ['ID', 'TITLE', 'TIME', 'TYPE', 'FILE_PATH', 'NOTE_ID']);
    if (resultSet.goToNextRow()) {
      const entry: NoteEntry = {
        id: resultSet.getLong(resultSet.getColumnIndex('ID')),
        title: resultSet.getString(resultSet.getColumnIndex('TITLE')),
        date: resultSet.getString(resultSet.getColumnIndex('TIME')),
        type: resultSet.getString(resultSet.getColumnIndex('TYPE')),
        filePath: resultSet.getString(resultSet.getColumnIndex('FILE_PATH')),
        noteId: resultSet.getString(resultSet.getColumnIndex('NOTE_ID')),
      };
      resultSet.close();
      return entry;
    }
    resultSet.close();
  } catch (error) {
    const err = error as BusinessError;
    hilog.error(DOMAIN, 'datastore', `Failed to query note. Code:${err.code}, message:${err.message}`);
  }
  return undefined;
}

/**
 * 按日期查询笔记列表（ARTICLE 类型）
 * @param date 日期字符串，格式：YYYY-MM-DD
 * @returns 笔记列表
 */
export async function GetNotesByDate(date: string): Promise<NoteEntry[]> {
  await ensureDbReady();
  if (store === undefined) return [];
  
  let entries: NoteEntry[] = [];

  let predicates = new relationalStore.RdbPredicates('NOTES');
  predicates.like('TIME', `${date}%`);
  predicates.orderByDesc('TIME');

  try {
    const resultSet = await store.query(predicates, ['ID', 'TITLE', 'TIME', 'TYPE', 'FILE_PATH', 'NOTE_ID']);

    while (resultSet.goToNextRow()) {
      const entry: NoteEntry = {
        id: resultSet.getLong(resultSet.getColumnIndex('ID')),
        title: resultSet.getString(resultSet.getColumnIndex('TITLE')),
        date: resultSet.getString(resultSet.getColumnIndex('TIME')),
        type: resultSet.getString(resultSet.getColumnIndex('TYPE')),
        filePath: resultSet.getString(resultSet.getColumnIndex('FILE_PATH')),
        noteId: resultSet.getString(resultSet.getColumnIndex('NOTE_ID')),
      };
      entries.push(entry);
    }

    resultSet.close();
    hilog.info(DOMAIN, 'datastore', `Query notes by date ${date}: ${entries.length} results`);
  } catch (error) {
    const err = error as BusinessError;
    hilog.error(DOMAIN, 'datastore', `Failed to query notes by date. Code:${err.code}, message:${err.message}`);
  }

  return entries;
}

/**
 * 查询所有笔记列表（ARTICLE 类型），按时间降序
 * @returns 笔记列表
 */
export async function GetAllNotes(): Promise<NoteEntry[]> {
  await ensureDbReady();
  if (store === undefined) return [];
  
  console.info(`[datastore] GetAllNotes 开始查询`);
  let entries: NoteEntry[] = [];

  let predicates = new relationalStore.RdbPredicates('NOTES');
  predicates.orderByDesc('TIME');

  try {
    const resultSet = await store.query(predicates, ['ID', 'TITLE', 'TIME', 'TYPE', 'FILE_PATH', 'NOTE_ID']);
    console.info(`[datastore] GetAllNotes 查询结果: columnCount=${resultSet.columnCount}`);

    while (resultSet.goToNextRow()) {
      const entry: NoteEntry = {
        id: resultSet.getLong(resultSet.getColumnIndex('ID')),
        title: resultSet.getString(resultSet.getColumnIndex('TITLE')),
        date: resultSet.getString(resultSet.getColumnIndex('TIME')),
        type: resultSet.getString(resultSet.getColumnIndex('TYPE')),
        filePath: resultSet.getString(resultSet.getColumnIndex('FILE_PATH')),
        noteId: resultSet.getString(resultSet.getColumnIndex('NOTE_ID')),
      };
      entries.push(entry);
      console.info(`[datastore] GetAllNotes 读取记录: id=${entry.id}, title=${entry.title}`);
    }

    resultSet.close();
    console.info(`[datastore] GetAllNotes 完成: 共 ${entries.length} 条记录`);
    hilog.info(DOMAIN, 'datastore', `Query all notes: ${entries.length} results`);
  } catch (error) {
    const err = error as BusinessError;
    console.error(`[datastore] GetAllNotes 查询失败: Code=${err.code}, message=${err.message}`);
    hilog.error(DOMAIN, 'datastore', `Failed to query all notes. Code:${err.code}, message:${err.message}`);
  }

  return entries;
}